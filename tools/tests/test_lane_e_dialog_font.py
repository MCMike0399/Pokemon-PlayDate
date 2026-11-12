"""Dialog boxes use pokered's tile font. Lane E has not applied this yet.

After applying tools/notes/lane-e-dialog-font.patch, run
`python3 tools/visual/compare.py <reviewed-baseline> <candidate> --protected-preservation`
and update baselines only for dialog-box pixels. Do not regenerate other catalog art.
The overworld, battle messages, and Oak's speech share the same glyphs.
▼ is drawn for prompt, para and cont. done draws none.
Typing and settled battle text share Dialog:draw. The battle menu uses that
box and GbFont. The hunk stays clear of the lines lane H's
lane-e-battle-text-flicker.patch anchors.
"""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-dialog-font.patch"

PROBE = r"""
function Class(name) _G[name] = _G[name] or {} end
function import() end
playdate = {graphics = {getFont = function() return {} end}}
dofile("Source/ui/dialog.lua")
assert(Dialog.showsArrow("prompt") == true)
assert(Dialog.showsArrow("para") == true)
assert(Dialog.showsArrow("cont") == true)
assert(Dialog.showsArrow("done") == false)
assert(Dialog.showsArrow(nil) == false)
dofile("Source/game/sourceText.lua")
dofile("Source/game/eventText.lua")
local function pages(recipe, ram)
    return EventText.pagesFrom({"t"}, function() return {source = "t.asm", recipe = recipe} end, ram)
end
local prompt = pages({
    {op = "text", text = "Which #MON"},
    {op = "line", text = "should I look at?"},
    {op = "control", source = "prompt"},
})
assert(prompt[1].ending == "prompt", prompt[1].ending)
assert(prompt[1].text == "Which POKEMON\nshould I look at?", prompt[1].text)
local paragraph = pages({
    {op = "text", text = "That is a decent"},
    {op = "line", text = "nickname!"},
    {op = "para", text = "How about it?"},
    {op = "control", source = "done"},
})
assert(paragraph[1].ending == "para", paragraph[1].ending)
assert(paragraph[2].text == "How about it?", paragraph[2].text)
assert(paragraph[2].ending == "done", paragraph[2].ending)
local nickname = pages({
    {op = "text", text = "Do you want to"},
    {op = "line", text = "give a nickname"},
    {op = "cont", text = "to @"},
    {op = "text_ram", symbol = "wNameBuffer"},
    {op = "text", text = "?"},
    {op = "control", source = "done"},
}, {wNameBuffer = "SQUIRTLE"})
assert(nickname[1].text == "Do you want to\ngive a nickname", nickname[1].text)
assert(nickname[1].ending == "cont", nickname[1].ending)
assert(nickname[2].text == "give a nickname\nto SQUIRTLE?", nickname[2].text)
assert(nickname[2].ending == "done", nickname[2].ending)
print("arrow-endings-ok")
"""


class LaneEDialogFontTests(unittest.TestCase):
    def test_dialog_font_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("--protected-preservation", patch)
        self.assertIn("dialog-box pixels", patch)
        self.assertIn("function Dialog.showsArrow", patch)

    def test_prompt_para_and_done_endings(self):
        scratch = Path(tempfile.mkdtemp(prefix="lane-e-dialog-"))
        try:
            completed = subprocess.run(
                ["git", "worktree", "add", "--detach", str(scratch), "HEAD"],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["git", "apply", str(PATCH)],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["lua", "-e", PROBE],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertIn("arrow-endings-ok", completed.stdout)
            battle = (scratch / "Source/battle/battleScene.lua").read_text()
            self.assertIn("function BattleScene:drawDialog", battle)
            self.assertIn("self:drawDialog(self.messageDialog)", battle)
            self.assertIn("self:drawDialog(self.settledDialog)", battle)
            self.assertNotIn('_wrapped("battle-message"', battle)
            self.assertIn("function BattleScene:drawCommandFrame", battle)
            self.assertIn("GbFont.drawBox", battle)
            self.assertNotIn('self:_text("what-will"', battle)
            # lane-e-battle-text-flicker.patch inserts between these anchors.
            self.assertIn(
                "gfx.setFont(gfx.getSystemFont())\n\n"
                "    -- Draw message box or menus.",
                battle)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    @unittest.expectedFailure
    def test_battle_text_uses_one_renderer(self):
        battle = (ROOT / "Source/battle/battleScene.lua").read_text()
        self.assertIn("self:drawDialog(self.messageDialog)", battle)
        self.assertIn("self:drawDialog(self.settledDialog)", battle)
        self.assertNotIn('_wrapped("battle-message"', battle)
        self.assertNotIn('self:_text("what-will"', battle)

    @unittest.expectedFailure
    def test_dialog_box_uses_the_tile_font(self):
        source = (ROOT / "Source/ui/dialog.lua").read_text()
        self.assertIn("GbFont.drawBox", source)
        self.assertIn("▼", source)
        self.assertIn("textBox(0, 12, 18, 4)", source)
        self.assertIn("function Dialog.showsArrow", source)
        event = (ROOT / "Source/game/eventText.lua").read_text()
        self.assertIn('return line1 .. "\\n" .. line2', event)
        self.assertNotIn("reflow to Playdate words", event)


if __name__ == "__main__":
    unittest.main()
