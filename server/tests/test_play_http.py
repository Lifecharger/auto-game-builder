"""Offline transport regression tests; no credentials or live uploads."""

import socket
import ssl
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.play_http import PlayHttp, PlayHTTPSConnection, UPLOAD_TIMEOUT_SECONDS

V6 = (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("2001:db8::1", 443, 0, 0))
V4 = (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("192.0.2.1", 443))


class PlayHttpTests(unittest.TestCase):
    def setUp(self):
        self.connection = PlayHTTPSConnection("play.example", timeout=540, proxy_info=None)
        self.connection._context = Mock()

    def connect_with(self, addresses, effects):
        with patch("core.play_http.socket.getaddrinfo", return_value=addresses), \
                patch.object(self.connection, "_connect_address", side_effect=effects) as attempt:
            self.connection.connect()
        return attempt

    def test_ipv6_success_needs_no_retry(self):
        attempt = self.connect_with([V6, V4], [None])
        self.assertEqual(attempt.call_count, 1)
        self.assertEqual(attempt.call_args.args[0], V6)

    def test_ipv6_timeout_retries_ipv4_once(self):
        attempt = self.connect_with([V6, V6, V4], [socket.timeout(), None])
        self.assertEqual([c.args[0] for c in attempt.call_args_list], [V6, V4])
        self.assertEqual(attempt.call_args_list[0].args[1], attempt.call_args_list[1].args[1])

    def test_ipv4_failure_propagates_without_more_retries(self):
        error = socket.timeout("IPv4 failed")
        with patch("core.play_http.socket.getaddrinfo", return_value=[V6, V4, V4]), \
                patch.object(self.connection, "_connect_address", side_effect=[socket.timeout(), error]) as attempt:
            with self.assertRaises(socket.timeout) as caught:
                self.connection.connect()
        self.assertIs(caught.exception, error)
        self.assertEqual(attempt.call_count, 2)

    def test_ipv4_timeout_and_ipv6_only_timeout_are_not_retried(self):
        for addresses in ([V4], [V6]):
            with self.subTest(addresses=addresses), \
                    patch("core.play_http.socket.getaddrinfo", return_value=addresses), \
                    patch.object(self.connection, "_connect_address", side_effect=socket.timeout()) as attempt:
                with self.assertRaises(socket.timeout):
                    self.connection.connect()
                self.assertEqual(attempt.call_count, 1)

    def test_certificate_error_is_not_retried(self):
        with patch("core.play_http.socket.getaddrinfo", return_value=[V6, V4]), \
                patch.object(self.connection, "_connect_address", side_effect=ssl.SSLError()) as attempt:
            with self.assertRaises(ssl.SSLError):
                self.connection.connect()
        self.assertEqual(attempt.call_count, 1)

    def test_socket_uses_resolved_address_and_preserves_tls_and_read_timeout(self):
        sock = Mock()
        with patch("core.play_http.socket.socket", return_value=sock), \
                patch("core.play_http.time.monotonic", return_value=100):
            self.connection._connect_address(V4, 130)
        sock.connect.assert_called_once_with(V4[4])
        sock.settimeout.assert_called_with(15)
        self.connection._context.wrap_socket.assert_called_once_with(sock, server_hostname="play.example")
        self.connection.sock.settimeout.assert_called_once_with(540)

    def test_failed_socket_is_closed(self):
        sock = Mock()
        sock.connect.side_effect = socket.timeout()
        with patch("core.play_http.socket.socket", return_value=sock), \
                patch("core.play_http.time.monotonic", return_value=100):
            with self.assertRaises(socket.timeout):
                self.connection._connect_address(V6, 130)
        sock.close.assert_called_once()
        self.assertIsNone(self.connection.sock)

    def test_exhausted_budget_does_not_open_socket(self):
        with patch("core.play_http.socket.socket") as create, \
                patch("core.play_http.time.monotonic", return_value=130):
            with self.assertRaises(socket.timeout):
                self.connection._connect_address(V4, 130)
        create.assert_not_called()

    def test_proxy_is_not_bypassed(self):
        self.connection.proxy_info = Mock()
        with patch("httplib2.HTTPSConnectionWithTimeout.connect") as original, \
                patch("core.play_http.socket.getaddrinfo") as resolve:
            self.connection.connect()
        original.assert_called_once()
        resolve.assert_not_called()

    def test_transport_is_local_and_preserves_resumable_uploads(self):
        original_resolver = socket.getaddrinfo
        http = PlayHttp()
        self.assertEqual(http.timeout, UPLOAD_TIMEOUT_SECONDS)
        self.assertNotIn(308, http.redirect_codes)
        self.assertIs(socket.getaddrinfo, original_resolver)
        with patch("httplib2.Http.request", return_value=({}, b"")) as request:
            http.request("https://oauth2.googleapis.com/token", method="POST", body=b"data")
        self.assertIs(request.call_args.args[-1], PlayHTTPSConnection)
        self.assertEqual(request.call_args.args[1:3], ("POST", b"data"))

    def test_read_timeout_does_not_replay_post_or_trigger_ipv4(self):
        connection = Mock()
        connection.sock = None
        connection.getresponse.side_effect = socket.timeout("read timeout")
        with self.assertRaises(socket.timeout):
            PlayHttp()._conn_request(connection, "/commit", "POST", b"data", {})
        connection.connect.assert_called_once()
        connection.request.assert_called_once_with("POST", "/commit", b"data", {})


if __name__ == "__main__":
    unittest.main()
