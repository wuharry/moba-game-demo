"""Small read-only DEX index plus narrowly checked in-place prototype edits."""
import hashlib
import struct
import zlib


class Dex:
    def __init__(self, data: bytes):
        self.data = data
        assert data[:4] == b'dex\n'
        count, off = struct.unpack_from('<II', data, 56)
        self.strings = []
        for i in range(count):
            ptr = struct.unpack_from('<I', data, off + i * 4)[0]
            _, ptr = self.uleb(ptr)
            end = data.index(b'\0', ptr)
            self.strings.append(data[ptr:end].decode('utf-8', errors='replace'))
        count, off = struct.unpack_from('<II', data, 64)
        self.types = [self.strings[struct.unpack_from('<I', data, off + i * 4)[0]] for i in range(count)]
        count, off = struct.unpack_from('<II', data, 72)
        self.protos = []
        for i in range(count):
            _, ret, params = struct.unpack_from('<III', data, off + i * 12)
            args = []
            if params:
                n = struct.unpack_from('<I', data, params)[0]
                args = [self.types[struct.unpack_from('<H', data, params + 4 + j * 2)[0]] for j in range(n)]
            self.protos.append('(' + ''.join(args) + ')' + self.types[ret])
        count, off = struct.unpack_from('<II', data, 88)
        self.methods = []
        for i in range(count):
            klass, proto, name = struct.unpack_from('<HHI', data, off + i * 8)
            self.methods.append((self.types[klass], self.strings[name], self.protos[proto]))
        count, off = struct.unpack_from('<II', data, 80)
        self.fields = []
        for i in range(count):
            klass, typ, name = struct.unpack_from('<HHI', data, off + i * 8)
            self.fields.append((self.types[klass], self.strings[name], self.types[typ]))
        count, off = struct.unpack_from('<II', data, 96)
        self.code = {}
        for i in range(count):
            encoded = struct.unpack_from('<I', data, off + i * 32 + 24)[0]
            if not encoded:
                continue
            counts = []
            for _ in range(4):
                n, encoded = self.uleb(encoded)
                counts.append(n)
            for _ in range(counts[0] + counts[1]):
                _, encoded = self.uleb(encoded)
                _, encoded = self.uleb(encoded)
            for n in counts[2:]:
                idx = 0
                for _ in range(n):
                    delta, encoded = self.uleb(encoded)
                    _, encoded = self.uleb(encoded)
                    code, encoded = self.uleb(encoded)
                    idx += delta
                    if code:
                        self.code[self.methods[idx]] = code

    def uleb(self, at):
        value = 0
        shift = 0
        while True:
            byte = self.data[at]
            at += 1
            value |= (byte & 127) << shift
            if not byte & 128:
                return value, at
            shift += 7

    def patch_installer_class_name(self, old_package: str) -> bytes:
        klass = 'L' + old_package.replace('.', '/') + '/MainActivity;'
        start = self.code[(klass, 'b', '()Z')]
        length = struct.unpack_from('<I', self.data, start + 12)[0] * 2
        start += 16
        code = bytearray(self.data[start:start + length])
        method_id = self.methods.index((klass, 'getPackageName', '()Ljava/lang/String;'))
        string_id = self.strings.index(old_package)
        assert string_id < 65536
        pattern = b'\x6e\x10' + struct.pack('<H', method_id) + b'\x04\x00\x0c\x03'
        assert code.count(pattern) == 1, 'Expected one class-name package lookup in MainActivity.b()'
        replacement = b'\x1a\x03' + struct.pack('<H', string_id) + b'\0' * 4
        at = code.index(pattern)
        data = bytearray(self.data)
        data[start + at:start + at + 8] = replacement
        data[12:32] = hashlib.sha1(data[32:]).digest()
        struct.pack_into('<I', data, 8, zlib.adler32(data[12:]) & 0xffffffff)
        return bytes(data)

    def patch_preverified_resources(self, old_package: str) -> bytes:
        """Prototype only: use the copied, externally hash-verified asset bundle.

        The original downloader expects its historical split archives, not the
        already assembled/upgraded files. Preserve native-library initialization.
        """
        klass = 'L' + old_package.replace('.', '/') + '/installer/utils/DownloadComponent;'
        data = bytearray(self.data)

        def replace(method, words):
            at = self.code[method]
            n = struct.unpack_from('<I', data, at + 12)[0]
            assert len(words) <= n
            encoded = struct.pack('<' + 'H' * len(words), *words)
            data[at + 16:at + 16 + len(encoded)] = encoded

        completed = self.fields.index((klass, 'm_isCompleted', 'Z'))
        # validateFiles has 22 registers; p0 is v19. Move it into v0 first.
        words = [0x0008, 19, 0x0216, 0]  # move-object/from16 v0,v19; const-wide/16 v2,0
        for field in ('mRequiredSize', 'mDownloadedSize', 'm_iRealRequiredSize', 'mTotalSize', 'mbRequired', 'mbRequiredJustArhive'):
            idx = self.fields.index((klass, field, 'J'))
            words += [0x025a, idx]  # iput-wide v2,v0,field
        words += [0x1112, 0x015c, completed, 0x0112, 0x010f]  # completed=true; return 0
        replace((klass, 'validateFiles', '(ZL' + old_package.replace('.', '/') + '/installer/GameInstaller;)I'), words)
        replace((klass, 'requestForNewVersion', '()Z'), [0x0012, 0x000f])
        data[12:32] = hashlib.sha1(data[32:]).digest()
        struct.pack_into('<I', data, 8, zlib.adler32(data[12:]) & 0xffffffff)
        return bytes(data)
