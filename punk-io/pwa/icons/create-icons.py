#!/usr/bin/env python3
"""Generate PWA icons for Punk.io"""
import struct, zlib, os

def create_png(width, height):
    """Create a simple gradient PNG icon with 'P' letter"""
    pixels = []
    for y in range(height):
        row = []
        for x in range(width):
            # Gradient from purple (#7c3aed) to pink (#ec4899)
            t = (x + y) / (width + height)
            r = int(124 + (236 - 124) * t)
            g = int(58 + (72 - 58) * t)
            b = int(237 + (153 - 237) * t)

            # Draw "P" letter region (centered, rough approximation)
            cx, cy = width // 2, height // 2
            # Letter P bounding box
            lx = width * 0.3
            rx = width * 0.7
            ty = height * 0.2
            by = height * 0.8

            in_letter = False
            # Vertical bar of P
            if lx <= x <= lx + width * 0.12 and ty <= y <= by:
                in_letter = True
            # Top horizontal
            if lx <= x <= rx - width * 0.05 and ty <= y <= ty + height * 0.1:
                in_letter = True
            # Middle horizontal
            if lx <= x <= rx - width * 0.05 and cy - height * 0.05 <= y <= cy + height * 0.05:
                in_letter = True
            # Right curve of P (approximation with vertical bar)
            if rx - width * 0.17 <= x <= rx - width * 0.05 and ty <= y <= cy + height * 0.05:
                in_letter = True

            if in_letter:
                r, g, b = 255, 255, 255

            row.extend([r, g, b, 255])
        pixels.append(bytes([0] + row))  # Filter byte + pixel data

    raw = b''.join(pixels)

    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = zlib.crc32(c) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + c + struct.pack('>I', crc)

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    compressed = zlib.compress(raw, 9)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', ihdr)
    png += chunk(b'IDAT', compressed)
    png += chunk(b'IEND', b'')
    return png

if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    for size in [192, 512]:
        data = create_png(size, size)
        path = os.path.join(script_dir, f'icon-{size}.png')
        with open(path, 'wb') as f:
            f.write(data)
        print(f'Created {path} ({len(data)} bytes)')
