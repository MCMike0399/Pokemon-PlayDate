"""Pinned, read-only inputs and the deliberately small RGBDS data grammar."""
from __future__ import annotations

import ast
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
import subprocess

REVISION = 'af519899719f0754965776faac0e836a3b906e6d'


class AudioError(ValueError):
    pass


@dataclass(frozen=True)
class Line:
    file: str
    number: int
    text: str
    comment: str = ''

    def fail(self, message):
        raise AudioError(f'{self.file}:{self.number}: {message}')

    @property
    def location(self):
        return f'{self.file}:{self.number}'


class Source:
    def __init__(self, root, revision=REVISION):
        self.root = Path(root).resolve()
        if revision != REVISION:
            raise AudioError(f'only pinned revision {REVISION} is supported')
        self.revision = revision
        actual = self.git('rev-parse', 'HEAD').decode().strip()
        if actual != revision:
            raise AudioError(f'source HEAD {actual}; required {revision}')
        self.hashes = {}
        self._texts = {}

    def git(self, *args):
        try:
            return subprocess.check_output(['git', '-C', str(self.root), *args], stderr=subprocess.PIPE)
        except subprocess.CalledProcessError as exc:
            raise AudioError(exc.stderr.decode().strip()) from exc

    def read(self, path):
        if Path(path).is_absolute() or '..' in Path(path).parts:
            raise AudioError(f'unsafe source path {path}')
        if path in self._texts:
            return self._texts[path]
        data = (self.root / path).read_bytes()
        pinned = self.git('show', f'{self.revision}:{path}')
        if data != pinned:
            raise AudioError(f'{path}:1: consumed source differs from pinned git blob')
        self.hashes[path] = hashlib.sha256(data).hexdigest()
        self._texts[path] = data.decode()
        return self._texts[path]

    def lines(self, path):
        active = True
        stack = []
        for number, raw in enumerate(self.read(path).splitlines(), 1):
            code, _, comment = raw.partition(';')
            line = Line(path, number, code.strip(), comment.strip())
            if line.text.startswith('IF '):
                expr = line.text[3:]
                if expr not in ('DEF(_RED)', 'DEF(_BLUE)'):
                    line.fail(f'unsupported conditional {expr}')
                stack.append((active, expr == 'DEF(_BLUE)', False))
                active = active and stack[-1][1]
            elif line.text == 'ELSE':
                if not stack or stack[-1][2]:
                    line.fail('unmatched/repeated ELSE')
                parent, condition, _ = stack[-1]
                stack[-1] = (parent, condition, True)
                active = parent and not condition
            elif line.text == 'ENDC':
                if not stack:
                    line.fail('unmatched ENDC')
                active = stack.pop()[0]
            elif active and line.text:
                yield line
        if stack:
            raise AudioError(f'{path}:{number}: unterminated IF')


def number(text, symbols=None):
    """Evaluate integer expressions only; never execute source Python."""
    symbols = symbols or {}
    text = text.strip()
    if text in symbols:
        return symbols[text]
    text = re.sub(r'\$([0-9a-fA-F]+)', r'0x\1', text)
    text = re.sub(r'%([01]+)', r'0b\1', text)
    operators = {ast.Add: lambda a, b: a+b, ast.Sub: lambda a, b: a-b,
                 ast.Mult: lambda a, b: a*b, ast.Div: lambda a, b: a//b,
                 ast.FloorDiv: lambda a, b: a//b, ast.BitOr: lambda a, b: a|b,
                 ast.BitAnd: lambda a, b: a&b, ast.LShift: lambda a, b: a<<b,
                 ast.RShift: lambda a, b: a>>b}

    def visit(node):
        if isinstance(node, ast.Constant) and type(node.value) is int:
            return node.value
        if isinstance(node, ast.Name) and node.id in symbols:
            return symbols[node.id]
        if isinstance(node, ast.BinOp) and type(node.op) in operators:
            return operators[type(node.op)](visit(node.left), visit(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.Invert)):
            return -visit(node.operand) if isinstance(node.op, ast.USub) else ~visit(node.operand)
        raise AudioError(f'unsupported integer expression {text!r}')
    try:
        return visit(ast.parse(text, mode='eval').body)
    except (SyntaxError, ZeroDivisionError) as exc:
        raise AudioError(f'invalid integer expression {text!r}') from exc


def parts(line):
    # Tabs occur between the opcode and operands too.
    fields = line.text.split(None, 1)
    return fields[0], [s.strip() for s in fields[1].split(',')] if len(fields) > 1 else []


def qualify(label, scope):
    return scope + label if label.startswith('.') else label
