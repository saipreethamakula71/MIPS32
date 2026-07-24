import sys
import os

def normalize_reg(r):
    r = r.strip().upper()
    if r.startswith('R'):
        return r
    return 'R' + r

def reg_to_int(r):
    r = r.strip().upper()
    if r.startswith('R'):
        return int(r[1:])
    return int(r)

def get_writes(inst):
    op = inst["op"]
    w = None
    if op in ["ADD", "SUB", "AND", "OR", "XOR", "NOR", "SLT"]:
        w = inst["args"][0]
    elif op in ["ADDI", "ANDI", "ORI", "XORI", "SLTI"]:
        w = inst["args"][0]
    elif op == "LOAD":
        w = inst["args"][0]
    
    if w and normalize_reg(w) == "R0":
        return None
    return normalize_reg(w) if w else None

def get_reads(inst):
    op = inst["op"]
    r = []
    if op in ["ADD", "SUB", "AND", "OR", "XOR", "NOR", "SLT"]:
        r = [inst["args"][1], inst["args"][2]]
    elif op in ["ADDI", "ANDI", "ORI", "XORI", "SLTI"]:
        r = [inst["args"][1]]
    elif op == "STORE":
        r = [inst["args"][0]]
    elif op in ["BEQZ", "BNEZ"]:
        r = [inst["args"][0]]
    
    return [normalize_reg(x) for x in r if normalize_reg(x) != "R0"]

def parse_line(line):
    # remove comments
    line = line.split(';')[0].split('#')[0].strip()
    if not line:
        return []
    
    parsed = []
    # check for label
    if ':' in line:
        parts = line.split(':', 1)
        label = parts[0].strip()
        if label:
            parsed.append({"op": "LABEL", "name": label, "raw": label + ":"})
        line = parts[1].strip()
        
    if not line:
        return parsed
        
    parts = line.split(None, 1)
    op = parts[0].upper()
    args = []
    if len(parts) > 1:
        args_str = parts[1]
        args = [x.strip() for x in args_str.split(',')]
        
    parsed.append({"op": op, "args": args, "raw": line})
    return parsed

def fix_hazards(instructions, mode="asm"):
    i = 0
    fixes_summary = []
    
    while i < len(instructions):
        inst = instructions[i]
        if inst["op"] == "LABEL":
            i += 1
            continue
            
        reads = get_reads(inst)
        max_nops_needed = 0
        stalling_reg = None
        
        for reg in reads:
            dist = 0
            for j in range(i - 1, -1, -1):
                prev_inst = instructions[j]
                if prev_inst["op"] == "LABEL":
                    continue
                dist += 1
                
                if prev_inst["op"] in ["JMP", "BEQZ", "BNEZ"]:
                    break
                    
                w = get_writes(prev_inst)
                if w == reg:
                    nops = 3 - dist
                    if nops > max_nops_needed:
                        max_nops_needed = nops
                        stalling_reg = reg
                    break
                
                if dist >= 3:
                    break
                    
        if max_nops_needed > 0:
            scheduled = False
            if mode == "asp":
                skipped_reads = set(reads)
                w_inst = get_writes(inst)
                skipped_writes = set([w_inst]) if w_inst else set()
                skipped_mem = inst["op"] in ["LOAD", "STORE"]
                
                candidate_idx = -1
                for k in range(i + 1, len(instructions)):
                    cand = instructions[k]
                    if cand["op"] == "LABEL" or cand["op"] in ["JMP", "BEQZ", "BNEZ"]:
                        break
                        
                    cand_reads = set(get_reads(cand))
                    cand_write = get_writes(cand)
                    
                    if cand["op"] in ["LOAD", "STORE"] and skipped_mem:
                        skipped_reads.update(cand_reads)
                        if cand_write: skipped_writes.add(cand_write)
                        skipped_mem = True
                        continue

                    if cand_reads.intersection(skipped_writes):
                        skipped_reads.update(cand_reads)
                        if cand_write: skipped_writes.add(cand_write)
                        if cand["op"] in ["LOAD", "STORE"]: skipped_mem = True
                        continue
                        
                    if cand_write and (cand_write in skipped_reads or cand_write in skipped_writes):
                        skipped_reads.update(cand_reads)
                        if cand_write: skipped_writes.add(cand_write)
                        if cand["op"] in ["LOAD", "STORE"]: skipped_mem = True
                        continue
                        
                    cand_hazard = False
                    for r in cand_reads:
                        dist = 0
                        for j in range(i - 1, -1, -1):
                            prev = instructions[j]
                            if prev["op"] == "LABEL": continue
                            dist += 1
                            if prev["op"] in ["JMP", "BEQZ", "BNEZ"]: break
                            if get_writes(prev) == r:
                                if dist < 3:
                                    cand_hazard = True
                                break
                            if dist >= 3: break
                        if cand_hazard: break
                        
                    if not cand_hazard:
                        candidate_idx = k
                        break
                        
                    skipped_reads.update(cand_reads)
                    if cand_write: skipped_writes.add(cand_write)
                    if cand["op"] in ["LOAD", "STORE"]: skipped_mem = True
                    
                if candidate_idx != -1:
                    cand_inst = instructions.pop(candidate_idx)
                    instructions.insert(i, cand_inst)
                    fixes_summary.append(f"Moved '{cand_inst['raw']}' before '{inst['raw']}' to avoid stalling on {stalling_reg}")
                    scheduled = True
                    i += 1
                    continue
                    
            if not scheduled:
                instructions.insert(i, {"op": "NOP", "args": [], "raw": "NOP"})
                fixes_summary.append(f"Inserted NOP before '{inst['raw']}' to fix hazard on {stalling_reg}")
                i += 1
                continue
                
        i += 1
        
    return fixes_summary

def encode_inst(inst, address_map):
    op = inst["op"]
    if op == "NOP":
        return 0x00000000
    
    # ALUR
    alur_opcodes = {"ADD": 0, "SUB": 1, "AND": 2, "OR": 3, "XOR": 4, "NOR": 5, "SLT": 6}
    if op in alur_opcodes:
        type_val = 0
        opcode = alur_opcodes[op]
        rd = reg_to_int(inst["args"][0])
        rs = reg_to_int(inst["args"][1])
        rt = reg_to_int(inst["args"][2])
        return (type_val << 30) | (opcode << 26) | (rd << 21) | (rt << 16) | (rs << 11)
        
    # ALUI
    alui_opcodes = {"ADDI": 0, "ANDI": 1, "ORI": 2, "XORI": 3, "SLTI": 4}
    if op in alui_opcodes:
        type_val = 1
        opcode = alui_opcodes[op]
        rd = reg_to_int(inst["args"][0])
        rt = reg_to_int(inst["args"][1])
        imm = int(inst["args"][2], 0)
        imm11 = imm & 0x7FF
        return (type_val << 30) | (opcode << 26) | (rd << 21) | (rt << 16) | (0 << 11) | imm11
        
    # MEM
    mem_opcodes = {"LOAD": 0, "STORE": 1}
    if op in mem_opcodes:
        type_val = 2
        opcode = mem_opcodes[op]
        rd = reg_to_int(inst["args"][0])
        addr_arg = inst["args"][1]
        if addr_arg in address_map:
            addr10 = address_map[addr_arg]
        else:
            addr10 = int(addr_arg, 0)
        addr10 = addr10 & 0x3FF
        return (type_val << 30) | (opcode << 26) | (rd << 21) | (addr10 << 11)
        
    # BRANCH
    branch_opcodes = {"BEQZ": 0, "BNEZ": 1, "JMP": 2}
    if op in branch_opcodes:
        type_val = 3
        opcode = branch_opcodes[op]
        if op == "JMP":
            rd = 0
            addr_arg = inst["args"][0]
        else:
            rd = reg_to_int(inst["args"][0])
            addr_arg = inst["args"][1]
            
        if addr_arg in address_map:
            addr10 = address_map[addr_arg]
        else:
            addr10 = int(addr_arg, 0)
        addr10 = addr10 & 0x3FF
        return (type_val << 30) | (opcode << 26) | (rd << 21) | (addr10 << 11)
        
    raise ValueError(f"Unknown instruction: {op}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python assembler.py <file.asm or file.asp>")
        sys.exit(1)
        
    filepath = sys.argv[1]
    ext = os.path.splitext(filepath)[1].lower()
    mode = "asp" if ext == ".asp" else "asm"
        
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    instructions = []
    for line in lines:
        instructions.extend(parse_line(line))
        
    fixes = fix_hazards(instructions, mode)
    
    address_map = {}
    addr = 0
    for inst in instructions:
        if inst["op"] == "LABEL":
            address_map[inst["name"]] = addr
        else:
            addr += 1
            
    machine_code = []
    for inst in instructions:
        if inst["op"] == "LABEL":
            continue
        code = encode_inst(inst, address_map)
        machine_code.append(code)
        
    out_filepath = os.path.splitext(filepath)[0] + ".hex"
    with open(out_filepath, 'w') as f:
        for code in machine_code:
            f.write(f"{code:08X}\n")
            
    print(f"Assembly complete. Generated {out_filepath}")
    if fixes:
        print(f"Data hazards fixed ({len(fixes)}):")
        for fix in fixes:
            print("  - " + fix)
    else:
        print("No data hazards found.")

if __name__ == "__main__":
    main()
