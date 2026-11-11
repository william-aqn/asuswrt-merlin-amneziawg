#!/usr/bin/env python3
"""Tiny TCP helper for the netns MSS experiment.

  mss-netns.py server <ip> <port>          accept connections forever; per connection print the
                                        MSS learned from the SYN and the bytes received
  mss-netns.py client <ip> <port> <bytes>  connect, print the MSS learned from the SYN-ACK, send
                                        <bytes> of payload, report whether it all went out
"""
import socket
import sys
import time


def server(ip, port):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((ip, port))
    srv.listen(8)
    while True:
        conn, _ = srv.accept()
        mss = conn.getsockopt(socket.IPPROTO_TCP, socket.TCP_MAXSEG)
        conn.settimeout(6)
        got = 0
        try:
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                got += len(chunk)
        except OSError:
            pass
        print("SERVER mss_from_syn=%d received=%d" % (mss, got), flush=True)
        conn.close()


def client(ip, port, nbytes):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(4)
    try:
        s.connect((ip, port))
    except OSError as exc:
        print("CLIENT connect_failed=%s" % exc)
        return 1
    mss = s.getsockopt(socket.IPPROTO_TCP, socket.TCP_MAXSEG)
    payload = b"x" * nbytes
    sent = 0
    t0 = time.time()
    s.settimeout(1)
    deadline = t0 + 6
    try:
        while sent < nbytes and time.time() < deadline:
            try:
                sent += s.send(payload[sent:sent + 65536])
            except socket.timeout:
                continue
    except OSError as exc:
        print("CLIENT send_error=%s" % exc)
    # Unsent/unacked bytes still queued in the kernel = the upload is stuck.
    time.sleep(1.5)
    queued = -1
    try:
        import fcntl
        import struct
        import termios
        queued = struct.unpack("i", fcntl.ioctl(s.fileno(), termios.TIOCOUTQ, b"\0\0\0\0"))[0]
    except Exception:
        pass
    print("CLIENT mss_from_synack=%d handed_to_kernel=%d of %d still_unacked=%d" % (mss, sent, nbytes, queued))
    s.close()
    return 0


if __name__ == "__main__":
    if sys.argv[1] == "server":
        server(sys.argv[2], int(sys.argv[3]))
    else:
        sys.exit(client(sys.argv[2], int(sys.argv[3]), int(sys.argv[4])))
