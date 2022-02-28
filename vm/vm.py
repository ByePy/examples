"""
ByePy - Simple VM Example
Copyright (C) 2022  Tim Fischer

vm.py

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Literal
import os

from dotenv import load_dotenv
from byepy import connect, DEFINE, DO, register_enum, register_composite, to_compile, SQL

load_dotenv()
connect(os.getenv("AUTH_STR"))

DEFINE(
    """
    SELECT;  -- Just to trigger the syntax highlighting in sublime text!

    -- Currently supprted VM instruction set
    --
    DROP TYPE IF EXISTS opcode CASCADE;
    CREATE TYPE opcode AS ENUM (
      'lod',  -- lod t, x       load literal x into target register Rt
      'mov',  -- mov t, s       move from source register Rs to target register Rt
      'jeq',  -- jeq t, s, @a   if Rt = Rs, jump to location a, else fall through
      'jmp',  -- jmp @a         jump to location a
      'add',  -- add t, s1, s2  Rt ← Rs1 + Rs2
      'sub',  -- add t, s1, s2  Rt ← Rs1 - Rs2
      'mul',  -- mul t, s1, s2  Rt ← Rs1 * Rs2
      'div',  -- div t, s1, s2  Rt ← Rs1 / Rs2
      'mod',  -- mod t, s1, s2  Rt ← Rs1 mod Rs2
      'hlt'   -- hlt s          halt program, result is register Rs
    );

    -- A single VM instruction
    --
    DROP TYPE IF EXISTS instruction CASCADE;
    CREATE TYPE instruction AS (
      loc   int,     -- location
      opc   opcode,  -- opcode
      reg1  int, -- ┐
      reg2  int, -- │ up to three work registers
      reg3  int  -- ┘
    );

    -- A program is a table of instructions
    --
    DROP TABLE IF EXISTS program CASCADE;
    CREATE TABLE program OF instruction;

    CREATE INDEX ip ON program USING btree (loc);

    -----------------------------------------------------------------------
    -- Program to compute the length of the Collatz sequence (also known as
    -- the "3N + 1 problem") for the value N held in register R1.  Program
    -- entry is at location 0.
    --
    INSERT INTO program(loc, opc, reg1, reg2, reg3) VALUES
      ( 0, 'lod', 3, 0   , NULL),
      ( 1, 'lod', 4, 1   , NULL),
      ( 2, 'lod', 5, 2   , NULL),
      ( 3, 'lod', 6, 3   , NULL),
      ( 4, 'mov', 1, 3   , NULL),
      ( 5, 'jeq', 0, 4   , 14  ),
      ( 6, 'add', 1, 1   , 4   ),
      ( 7, 'mod', 2, 0   , 5   ),
      ( 8, 'jeq', 2, 4   , 11  ),
      ( 9, 'div', 0, 0   , 5   ),
      (10, 'jmp', 5, NULL, NULL),
      (11, 'mul', 0, 0   , 6   ),
      (12, 'add', 0, 0   , 4   ),
      (13, 'jmp', 5, NULL, NULL),
      (14, 'hlt', 1, NULL, NULL);

    -- Program to compute the Nth element of the Padovan sequence
    -- (see https://oeis.org/A000931) for value N held in register R1.
    -- Program entry is at location 0.

    -- INSERT INTO program(loc, opc, reg1, reg2, reg3) VALUES
    --   ( 0, 'lod', 1, 1,    NULL),
    --   ( 1, 'lod', 2, 0,    NULL),
    --   ( 2, 'lod', 3, 0,    NULL),
    --   ( 3, 'lod', 5, 0,    NULL),
    --   ( 4, 'lod', 6, 1,    NULL),
    --   ( 5, 'jeq', 0, 5,    15  ),
    --   ( 6, 'jeq', 0, 6,    16  ),
    --   ( 7, 'sub', 0, 0,    6   ),
    --   ( 8, 'sub', 0, 0,    6   ),
    --   ( 9, 'jeq', 0, 5,    17  ),
    --   (10, 'add', 4, 1,    2   ),
    --   (11, 'mov', 1, 2,    NULL),
    --   (12, 'mov', 2, 3,    NULL),
    --   (13, 'mov', 3, 4,    NULL),
    --   (14, 'jmp', 8, NULL, NULL),
    --   (15, 'hlt', 1, NULL, NULL),
    --   (16, 'hlt', 2, NULL, NULL),
    --   (17, 'hlt', 3, NULL, NULL);
    """
)


OpCode = Literal[
    'lod',
    'mov',
    'jeq',
    'jmp',
    'add',
    'sub',
    'mul',
    'div',
    'mod',
    'hlt'
]
register_enum('opcode', OpCode)


@register_composite
@dataclass
class Instruction:
  loc: int
  opc: OpCode
  reg1: int
  reg2: int
  reg3: int


@to_compile
def run(regs: list[int]) -> int:
    ip: int = 0

    while True:
        ins: Instruction = SQL(
            """
            SELECT p :: instruction
            FROM   program AS p
            WHERE  p.loc = $1
            """,
            [ip]
        )
        ip += 1

        if ins.opc == 'lod':
            regs[ins.reg1] = ins.reg2
        elif ins.opc == 'mov':
            regs[ins.reg1] = regs[ins.reg2]
        elif ins.opc == 'jeq':
            if regs[ins.reg1] == regs[ins.reg2]:
                ip = ins.reg3
        elif ins.opc == 'jmp':
            ip = ins.reg1
        elif ins.opc == 'add':
            regs[ins.reg1] = regs[ins.reg2] + regs[ins.reg3]
        elif ins.opc == 'sub':
            regs[ins.reg1] = regs[ins.reg2] - regs[ins.reg3]
        elif ins.opc == 'mul':
            regs[ins.reg1] = regs[ins.reg2] * regs[ins.reg3]
        elif ins.opc == 'div':
            regs[ins.reg1] = regs[ins.reg2] / regs[ins.reg3]
        elif ins.opc == 'mod':
            regs[ins.reg1] = regs[ins.reg2] % regs[ins.reg3]
        elif ins.opc == 'hlt':
            return regs[ins.reg1]


with open(Path(__file__).parent / "vm.sql", "r") as f:
    DO(f.read())

def run_comp(regs: list[int]) -> int:
    return SQL("SELECT run_start($1);", [regs])


if __name__ == "__main__":
    from time import time
    funcs = {
        "python": run,
        "byepy": run_comp,
    }

    for name, func in funcs.items():
        start = time()
        for i in range(1, 1001):
            func([i,0,0,0,0,0,0])
        end = time()
        print(name, (end - start) * 1000)

