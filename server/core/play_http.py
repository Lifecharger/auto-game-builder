"""Upload-local HTTPS transport with a bounded IPv4 connection retry."""

import logging
import socket
import ssl
import time

import httplib2

logger = logging.getLogger(__name__)
CONNECT_TIMEOUT_SECONDS = 15
CONNECT_BUDGET_SECONDS = 30
UPLOAD_TIMEOUT_SECONDS = 540


class PlayHTTPSConnection(httplib2.HTTPSConnectionWithTimeout):
    def _connect_address(self, address: tuple, deadline: float) -> None:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise socket.timeout("Play connection budget exhausted")
        family, socktype, proto, _, sockaddr = address
        sock = socket.socket(family, socktype, proto)
        try:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            sock.settimeout(min(CONNECT_TIMEOUT_SECONDS, remaining))
            sock.connect(sockaddr)
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise socket.timeout("Play connection budget exhausted")
            sock.settimeout(min(CONNECT_TIMEOUT_SECONDS, remaining))
            # Keep the DNS hostname for SNI and certificate verification.
            self.sock = self._context.wrap_socket(sock, server_hostname=self.host)
            self.sock.settimeout(self.timeout)
        except BaseException:
            sock.close()
            if self.sock is not None:
                self.sock.close()
                self.sock = None
            raise

    def connect(self) -> None:
        if self.proxy_info and self.proxy_info.isgood() and self.proxy_info.applies_to(self.host):
            # Respect configured proxies; never bypass their routing/authentication.
            return super().connect()
        addresses = socket.getaddrinfo(self.host, self.port, 0, socket.SOCK_STREAM)
        deadline = time.monotonic() + CONNECT_BUDGET_SECONDS
        last_error = OSError("No addresses available for Play HTTPS connection")
        for address in addresses:
            try:
                self._connect_address(address, deadline)
                return
            except (ssl.SSLError, ssl.CertificateError):
                raise
            except socket.timeout:
                ipv4 = next((a for a in addresses if a[0] == socket.AF_INET), None)
                if address[0] != socket.AF_INET6 or ipv4 is None:
                    raise
                logger.warning("Play IPv6 connection timed out; retrying once over IPv4")
                self._connect_address(ipv4, deadline)
                return
            except OSError as error:
                last_error = error
        raise last_error


class PlayHttp(httplib2.Http):
    def __init__(self) -> None:
        super().__init__(timeout=UPLOAD_TIMEOUT_SECONDS)
        # 308 is a resumable-upload response, not a redirect.
        self.redirect_codes = self.redirect_codes - {308}

    def request(self, uri, method="GET", body=None, headers=None,
                redirections=httplib2.DEFAULT_MAX_REDIRECTS, connection_type=None):
        if connection_type is None and uri.lower().startswith("https://"):
            connection_type = PlayHTTPSConnection
        return super().request(uri, method, body, headers, redirections, connection_type)
