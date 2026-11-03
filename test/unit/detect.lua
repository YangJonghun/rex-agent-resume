local t = require("unit.lib")
local detect = require("rex-agent-resume.detect")
local eq = t.eq

eq(detect.agent("/usr/local/bin/claude-code --resume x"), "claude", "aliases are recognized, like herdr")
eq(detect.agent("Claude.EXE"), "claude", "names are compared lowercased without extensions")
eq(detect.agent("node --require ./hook.js /usr/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js"), "pi", "pi recognized from its npm package path")
eq(detect.agent("bun /x/node_modules/@qwen-code/qwen-code/dist/index.js"), "qwen", "qwen recognized from its npm package path")
eq(detect.agent("node -e codex"), nil, "inline code is not an agent")
eq(detect.agent("python3 -m hermes"), nil, "python -m is not taken as a script")
eq(detect.agent("zsh -c claude"), nil, "a shell running a command string is not the agent")
eq(detect.agent("bash /h/bin/kilo"), "kilo", "a shell running an agent script is")
local bootstrap = "import os, re, sys\\012os.environ.pop('PYTHONHOME', None)\\012os.environ.pop('PYTHONPATH', None)\\012sys.path.insert(0, '/h/.hermes/app')\\012if sys.argv[1:2] == ['--print-runtime-command']: sys.dont_write_bytecode = True\\012from hermes_constants import get_default_hermes_root\\012os.environ['HERMES_HOME'] = os.environ.get('HERMES_HOME') or str(get_default_hermes_root())\\012if sys.argv[1:2] == ['--print-runtime-command']:\\012    from pathlib import Path\\012    from hermes_cli._launchers import print_runtime_command\\012    print_runtime_command(Path('/h/.hermes/app'), sys.argv[2:])\\012    sys.exit(0)\\012import hermes_bootstrap\\012if sys.argv[1:2] == ['--run-module']:\\012    import runpy\\012    if len(sys.argv) < 3: sys.exit('hermes: --run-module needs a module')\\012    module = sys.argv.pop(2)\\012    del sys.argv[1]\\012    runpy.run_module(module, run_name='__main__', alter_sys=True)\\012    sys.exit(0)\\012from hermes_cli.main import main\\012sys.argv[0] = re.sub(r'(-script\\.pyw|\\.exe)?$', '', sys.argv[0])\\012sys.exit(main())\\012"
eq(detect.agent("/h/.hermes/venv/bin/python3 -I -c " .. bootstrap .. " --resume h1"), "hermes", "hermes started by its installer's bootstrap")
eq(detect.agent("/h/.hermes/venv/bin/python3 -I -c " .. bootstrap:gsub("/h/.hermes/app'%)", "/other')", 1)), nil, "both bootstrap roots must agree")
