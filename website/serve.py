import http.server
import socket
import socketserver
import os
import sys
import webbrowser

PORT = 8080

def get_lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return '127.0.0.1'

class RangeRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP Request handler supporting Range requests for smooth APK & ZIP downloads."""
    
    def end_headers(self):
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

def run_server():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    lan_ip = get_lan_ip()
    url = f"http://{lan_ip}:{PORT}"
    local_url = f"http://localhost:{PORT}"

    print("=" * 65)
    print("      UNIVERSAL PC REMOTE — DOWNLOAD & HOSTING SERVER")
    print("=" * 65)
    print(f"\n  [OK] Server running successfully!")
    print(f"\n  -> Open on PC Browser:    {local_url}")
    print(f"  -> Open on Mobile Phone:   {url}")
    print("\n  Tip: Ensure your phone and PC are connected to the same")
    print("  Wi-Fi network or mobile hotspot to download the APK directly.")
    print("=" * 65)
    print("\nPress Ctrl+C to stop the server anytime.\n")

    # Open local browser automatically
    try:
        webbrowser.open(local_url)
    except Exception:
        pass

    with socketserver.TCPServer(("", PORT), RangeRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")

if __name__ == '__main__':
    run_server()
