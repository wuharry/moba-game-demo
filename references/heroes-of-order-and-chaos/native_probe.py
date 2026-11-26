"""Read-only ELF64 symbol/disassembly inspection for the installed HOC build."""
from pathlib import Path
import argparse
import bisect
import json
import re
import struct

import capstone
from capstone.arm64 import ARM64_OP_IMM, ARM64_OP_REG

ROOT = Path(__file__).resolve().parent
DATA = (ROOT / 'analysis/lib/arm64-v8a/libAndroid.so').read_bytes()
SYMBOLS = json.loads((ROOT / 'analysis/libAndroid.so.symbols.json').read_text())
SHOFF = struct.unpack_from('<Q', DATA, 40)[0]
SHENT, SHNUM, SHSTR = struct.unpack_from('<HHH', DATA, 58)
RAW = [struct.unpack_from('<IIQQQQIIQQ', DATA, SHOFF + i * SHENT) for i in range(SHNUM)]
STRINGS = DATA[RAW[SHSTR][4]:RAW[SHSTR][4] + RAW[SHSTR][5]]
SECTIONS = {STRINGS[s[0]:STRINGS.find(b'\0', s[0])].decode(): s for s in RAW}
NAMES = {int(s['address'], 16): s['name'] for s in SYMBOLS if int(s['address'], 16)}
GOT = {}


def offset(address: int) -> int | None:
    for s in RAW:
        if s[1] != 8 and s[3] <= address < s[3] + s[5]:
            return s[4] + address - s[3]
    return None


def load_relocations() -> None:
    dyn = SECTIONS['.dynsym']
    st = RAW[dyn[6]]
    strings = DATA[st[4]:st[4] + st[5]]
    for name, sec in SECTIONS.items():
        if sec[1] != 4:
            continue
        for i, pos in enumerate(range(sec[4], sec[4] + sec[5], sec[9])):
            dest, info, addend = struct.unpack_from('<QQq', DATA, pos)
            idx = info >> 32
            if idx:
                n, _, _, _, value, _ = struct.unpack_from('<IBBHQQ', DATA, dyn[4] + idx * dyn[9])
                sym = strings[n:strings.find(b'\0', n)].decode(errors='replace')
                GOT[dest] = (value, sym)
                if name == '.rela.plt':
                    NAMES[SECTIONS['.plt'][3] + 32 + i * 16] = sym + '@plt'
            elif info & 0xffffffff == 1027:
                GOT[dest] = (addend, NAMES.get(addend, ''))


def describe(address: int) -> str:
    if address in NAMES:
        return NAMES[address]
    pos = offset(address)
    if pos is None:
        return ''
    raw = DATA[pos:pos + 180].split(b'\0', 1)[0]
    if len(raw) >= 4 and all(32 <= x < 127 or x in (9, 10, 13) for x in raw):
        return repr(raw.decode())
    return ''


def disassemble(symbol: dict, calls_only: bool = False) -> list[str]:
    address = int(symbol['address'], 16)
    pos = offset(address)
    if pos is None:
        return []
    engine = capstone.Cs(capstone.CS_ARCH_ARM64, capstone.CS_MODE_LITTLE_ENDIAN)
    engine.detail = True
    lines = [f"\n{symbol['name']} {address:#x} bytes={symbol['size']}"]
    registers = {}
    for ins in engine.disasm(DATA[pos:pos + symbol['size']], address):
        args = ins.operands
        note = ''
        if ins.mnemonic in ('b', 'bl') and args[0].type == ARM64_OP_IMM:
            note = describe(args[0].imm)
        elif ins.mnemonic in ('adr', 'adrp'):
            registers[args[0].reg] = args[1].imm
            note = describe(args[1].imm)
        elif ins.mnemonic == 'add' and len(args) == 3 and args[2].type == ARM64_OP_IMM:
            base = registers.get(args[1].reg)
            if base is not None:
                registers[args[0].reg] = base + args[2].imm
                note = describe(base + args[2].imm)
        elif ins.mnemonic == 'ldr' and len(args) == 2 and args[1].type == capstone.arm64.ARM64_OP_MEM:
            base = registers.get(args[1].mem.base)
            if base is not None:
                target = base + args[1].mem.disp
                if target in GOT:
                    registers[args[0].reg], note = GOT[target]
                else:
                    note = describe(target)
        if not calls_only or ins.mnemonic in ('b', 'bl', 'blr') or note:
            lines.append(f'{ins.address:08x}: {ins.mnemonic:8} {ins.op_str:42} {note}')
    return lines


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('pattern')
    parser.add_argument('--disassemble', action='store_true')
    parser.add_argument('--calls', action='store_true')
    parser.add_argument('--output')
    args = parser.parse_args()
    load_relocations()
    found = sorted([s for s in SYMBOLS if re.search(args.pattern, s['name'])], key=lambda s: s['name'])
    lines = []
    for s in found:
        if args.disassemble:
            lines.extend(disassemble(s, args.calls))
        else:
            lines.append(f"{s['address']:12} {s['size']:7} {s['name']}")
    lines.append(f'\nMATCHES {len(found)}')
    text = '\n'.join(lines)
    if args.output:
        (ROOT / 'analysis' / args.output).write_text(text, encoding='utf-8')
        print(args.output, len(found), 'symbols', len(lines), 'lines')
    else:
        print(text)
