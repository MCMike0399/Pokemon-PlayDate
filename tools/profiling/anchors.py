"""Fail closed when the production instrumentation seam changes."""
def replace(text, before, after):
    if text.count(before) != 1:
        raise ValueError('profiling anchor changed: ' + before[:100])
    return text.replace(before, after, 1)
