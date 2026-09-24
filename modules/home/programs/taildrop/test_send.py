import unittest
from unittest.mock import patch
import subprocess

import send


class TaildropTests(unittest.TestCase):
    def peer(self, ip, name, online=True):
        return {"TailscaleIPs": [ip], "DNSName": name + ".example.ts.net.",
                "HostName": name, "Online": online, "OS": "linux"}

    def test_eligibility_online_filter_and_nickname_order(self):
        peers = {
            "a": self.peer("100.64.0.1", "server"),
            "b": self.peer("100.64.0.2", "phone"),
            "c": self.peer("100.64.0.3", "offline", False),
            "d": self.peer("100.64.0.4", "ineligible"),
        }
        devices = send.discover_devices(
            {"Peer": peers}, "100.64.0.1 server\n100.64.0.2 phone\n100.64.0.3 offline\n",
            {"phone": "Z phone"},
        )
        self.assertEqual([d[2] for d in devices], ["100.64.0.2", "100.64.0.1"])
        self.assertIn("Z phone", devices[0][3])

    def test_nickname_precedence_and_ipv6(self):
        peer = self.peer("fd7a::1", "phone")
        for nicknames, expected in [
            ({"fd7a::1": "IP", "phone": "Short"}, "IP"),
            ({"phone.example.ts.net": "DNS", "phone": "Short"}, "DNS"),
            ({"phone": "Short"}, "Short"),
        ]:
            with self.subTest(nicknames=nicknames):
                result = send.discover_devices({"Peer": {"a": peer}}, "fd7a::1 phone", nicknames)
                self.assertTrue(result[0][3].startswith(expected + " —"))

    def test_empty_peers(self):
        self.assertEqual(send.discover_devices({"Peer": None}, "", {}), [])

    @patch("send.dialog")
    @patch("send.subprocess.run")
    @patch("send.Path.is_file", return_value=True)
    @patch("send.Path.read_text", return_value="{}")
    def test_cancel_does_not_send(self, read, is_file, run, dialog):
        run.side_effect = [
            subprocess.CompletedProcess([], 0, '{"BackendState":"Running","Peer":'
                '{"a":{"TailscaleIPs":["100.64.0.1"],"Online":true}}}'),
            subprocess.CompletedProcess([], 0, "100.64.0.1 phone"),
        ]
        dialog.return_value = subprocess.CompletedProcess([], 1, "")
        with patch("sys.argv", ["send.py", "config.json", "a file.txt"]):
            send.main()
        self.assertEqual(run.call_count, 2)


if __name__ == "__main__":
    unittest.main()
