# lifecharger_testlab

One Android method for the Lifecharger analytics client: `isTestLab` on the `lifecharger/testlab` channel returns
true on Firebase Test Lab and Google Play pre-launch-report devices (`Settings.System "firebase.test.lab" == "true"`,
Google's documented check). The client then sends `test_device` and the analytics server leaves the install out
of every report.

Copied into each Flutter app at `packages/lifecharger_testlab/` by the shared Lifecharger client sync tool
and added to pubspec as a path dependency. Without it the client logs once that the check is unavailable.
