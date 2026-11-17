<p align="center">
  <a href="README.md">English</a> · 한국어
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-666666?labelColor=333333" alt="Platform: macOS | Linux" />
</p>

# rex-agent-resume

> [!WARNING]
> Rex는 아직 베타예요. 서버 API, Lua 런타임, 복원 동작이 어느 릴리스에서든 바뀔 수 있어서, Rex를 업데이트한 뒤 rex-agent-resume이 예고 없이 동작하지 않을 수 있어요.

[Rex](https://www.superlogical.com/rex) 서버가 다시 시작되면 Rex는 세션, 창, 패널을 되살리지만, 패널은 모두 빈 셸로 돌아와요. 그 안에서 돌던 프로그램은 사라져요.

rex-agent-resume은 패널마다 무엇이 돌고 있었는지 기억해 뒀다가, 재시작한 뒤 같은 패널에서 다시 실행해요.

- **AI 코딩 에이전트:** Claude Code, Codex 등 [18종](#지원하는-에이전트)은 설치만 하면 보던 대화로 다시 열려요. 대부분은 같은 모델과 모드로 돌아와요.
- **직접 만든 에이전트나 도구:** Vim처럼 다른 프로그램도 "다시 여는 명령"을 한 번 등록해 두면 같이 다시 열려요.

## 시작하기

1. Rex 버전을 확인하세요. 세션 복원이 들어간 ge6592f(2026-10-30) 이상이어야 하고, 이 명령이 `8` 이상을 보여야 해요.

   ```sh
   rex api call server.status | jq .api_revision
   ```

2. 설치하세요. 설치된 에이전트를 찾아 연결하고, Rex에도 연결해요. Linux에서는 [Rex 서버](https://www.superlogical.com/rex/docs/linux/installation)가 도는 기기에서 실행하세요.

   ```sh
   curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh
   ```

3. 끝이에요. 평소처럼 Rex 패널에서 에이전트를 쓰면 돼요.

같은 명령을 다시 실행하면 최신 버전으로 업데이트돼요. 특정 [릴리스](https://github.com/YangJonghun/rex-agent-resume/releases)를 설치하려면 버전을 지정하세요.

```sh
curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | REX_AGENT_RESUME_REF=v0.1.0-beta.1 sh
```

`jq`가 필요해요. macOS에는 `/usr/bin/jq`가 기본으로 있고, Linux에서는 패키지 관리자로 설치하세요.

## 사용법

설치 시 자동으로 적용돼요. 단, 설치할 때 이미 실행되고 있던 세션에는 적용되지 않을 수 있어요. 그런 세션은 한 번 다시 시작하세요.

아래 액션으로 자동 재개를 끄거나, 에이전트에 넣은 훅과 플러그인을 제거할 수 있어요.

### 액션

⌘⇧P로 명령 팔레트를 열고 `Agent Resume`을 검색하세요. `rex do <이름>`으로도 실행할 수 있어요.

| 팔레트 제목 | 이름 | 하는 일 |
| --- | --- | --- |
| Turn Off Agent Resume on Startup / Turn On Agent Resume on Startup | `agent_resume_toggle` | 재시작할 때 자동으로 다시 여는 걸 끄거나 켜요 |
| Restore Approval-Skipping Modes on Resume / Stop Restoring Approval-Skipping Modes on Resume | `agent_resume_skip_approvals_toggle` | `--dangerously-skip-permissions`처럼 묻지 않고 도구를 실행하는 모드도 되살려요. 기본은 꺼져 있어요. [언제 켜나요](#승인-생략-모드) |
| Uninstall rex-agent-resume | `agent_resume_uninstall` | 훅, 플러그인, Rex 설정을 빼요 |
| Register Resume Command for This Pane | `agent_resume_hint` | 프로그램이 다시 여는 명령을 등록할 때 써요 |

자동 재개를 꺼 둔 상태에서 서버가 다시 시작됐다면, 토글로 다시 켤 때 바로 재개해요.

## 지원하는 에이전트

모든 에이전트는 자기 재개 명령으로 보던 대화를 다시 열어요. 대부분은 모델과 모드도 스스로 되살려요. 에이전트가 잊는 옵션이 있으면 rex-agent-resume이 명령에 덧붙여요. 에이전트가 스스로 되살리는 것은 각 에이전트의 소스 코드나 문서를 보고 정리했고, 실제 에이전트로 확인한 건 Claude Code와 Codex뿐이에요.

| 에이전트 | 재개 명령 | 연결 방식 | 스스로 되살리는 것 | rex-agent-resume이 덧붙이는 것 |
| --- | --- | --- | --- | --- |
| Claude Code | `claude --resume <id>` | 훅 | 모델, 에이전트, 권한 모드(Manual과 bypass 제외) | effort, Manual 모드, bypass 모드* |
| Codex | `codex --no-daemon resume <id>` | 훅 | 모델, effort, 승인, 샌드박스, plan 모드 | — |
| GitHub Copilot CLI | `copilot --resume=<id>` | 훅 | 모델, 모드, 커스텀 에이전트 | — |
| Cursor Agent CLI | `cursor-agent --resume <id>` | 훅 | 모델, 모드, 승인 모드 | — |
| Droid | `droid --resume <id>` | 훅 | 모델, effort, 자율 수준 | — |
| Devin CLI | `devin --resume <id>` | 훅 | 모델, 프로필 | 권한 모드†, dangerous 모드*†, `--sandbox`† |
| Kimi Code CLI | `kimi --session <id>` | 훅 | 모델, effort, 권한 모드, plan 모드 | — |
| Hermes Agent | `hermes --resume <id>` | 플러그인 | 모델, reasoning, yolo 모드 | — |
| Letta Code | `letta --conversation <id>` | 훅 | 모델, effort | 권한 모드†, unrestricted 모드*† |
| OpenCode | `opencode --session <id>` | 플러그인 | 모델, 에이전트, effort | `--auto`*† |
| Kilo Code CLI | `kilo --session <id>` | 플러그인 | 모델, 에이전트, effort | `--auto`*† |
| Pi | `pi --session <id>` | 확장 | 모델, thinking level | — |
| OMP | `omp --resume=<id>` | 확장 | 모델, thinking level, 모드 | 승인 모드†, yolo 모드*†, `--profile`† |
| MastraCode | `mastracode resume <id>` | 훅 | 모드, 모델, thinking level, 권한 규칙 | — |
| Qwen Code | `qwen --resume <id>` | 훅 | — | 모델, 인증 방식, 승인 모드, yolo 모드* |
| Qoder CLI | `qodercli --resume <id>` | 훅 | 모델, effort | 권한 모드, yolo 모드* |
| Grok CLI | `grok --resume <id>` | 훅 | 모델, effort, 샌드박스, plan 모드 | — |
| Antigravity CLI | `agy --conversation <id>` | 훅 | 에이전트, 전역 설정 파일의 모델과 모드 | 모드†, `--sandbox`†, `--dangerously-skip-permissions`*† |

\* **Restore Approval-Skipping Modes on Resume** 설정을 켰을 때만 덧붙여요. [승인 생략 모드](#승인-생략-모드)를 보세요.

† 에이전트를 처음 실행한 명령에서 읽어요. 그래서 에이전트 안에서 바꾼 값은 사라져요. 나머지는 세션 중에 바꾼 값을 따라가요.

### 승인 생략 모드

`claude --dangerously-skip-permissions`, `qwen --yolo`, `kilo --auto`처럼 묻지 않고 도구를 실행하는 모드를 쓰지 않는다면 이 절은 넘어가도 돼요. 표에서 *가 붙은 옵션이 이런 모드예요. rex-agent-resume은 **Restore Approval-Skipping Modes on Resume** 설정을 켰을 때만 이 모드를 다시 붙여요. 설정은 모든 에이전트에 하나예요.

- 샌드박스 없이 이런 모드로 실행한다면 켜세요. 재시작한 뒤에도 첫 승인 요청에서 멈추지 않고 계속 일해요.
- macOS의 `sandbox-exec`나 Linux의 `bwrap` 같은 샌드박스 안에서만 이런 모드를 쓴다면 꺼 두세요. rex-agent-resume은 에이전트를 샌드박스 명령이 아니라 재개 명령으로 다시 열어요. 설정을 켜면 에이전트가 승인 요청도 샌드박스도 없이 돌아와요.

표에 \* 표시가 없는 에이전트는 이 설정을 켜든 끄든 똑같이 돌아와요. Codex, Cursor, Droid, Kimi, Hermes는 이 모드를 스스로 되살리고, Copilot도 그런 것으로 보여요. Grok과 MastraCode는 자기 설정 파일에서 가져오고, Pi에는 이런 모드가 없어요. 이 에이전트들을 샌드박스 안에서 이런 모드로 쓴다면, 샌드박스 밖에서 돌아오지 않게 하는 방법은 **Turn Off Agent Resume on Startup**뿐이에요. 이건 모든 에이전트의 자동 재개를 꺼요.

## 어떻게 동작하나요

Claude Code를 예로 들면 아래와 같은 순서로 동작해요.

1. **설치할 때.** Claude Code의 세션 시작 훅에 우리 스크립트(`rex-agent-resume-hook`)를 넣어요.
2. **대화를 시작하거나 바꿀 때.** Claude Code가 훅을 실행하면서 세션 ID를 넘겨요. 우리 스크립트는 "이 패널에는 `claude`, 세션은 `abc`"라고 적어 둬요. 새 대화로 바꾸면 덮어써요.
3. **켜져 있는 동안 계속.** Rex 서버 안에서 도는 감시자가 "지금 앞에 에이전트가 떠 있는 패널" 목록을 저장해요. 에이전트의 훅이 실행되면 바로, 패널에 변화가 있으면 2초 뒤에, 아무 일이 없어도 1분마다 저장해요. 에이전트를 끄고 셸로 돌아온 패널은 목록에서 빠져요.
4. **서버가 꺼질 때.** 아무것도 하지 않아요. 3번에서 저장해 둔 목록이 남아 있어요.
5. **서버가 다시 켜질 때.** Rex가 패널을 빈 셸로 되살리면, 감시자가 저장해 둔 목록을 읽고 각 패널에 `claude --resume abc`를 대신 입력해요. [에이전트가 잊는 옵션](#지원하는-에이전트)이 있으면 함께 붙여요.

에이전트마다 다른 건 2번뿐이에요. 대부분은 훅이, OpenCode 같은 일부는 플러그인이 우리 스크립트를 불러요. Vim이나 직접 만든 도구는 [프로그램이 직접](#직접-만든-에이전트나-도구-등록하기) 알려 줘요.

정리하면, Rex 서버가 켜져 있는 동안 스냅샷을 기록해 두고 다시 켜졌을 때 그걸 읽어서 실행해요. 꺼지는 순간에 하는 일이 없어서 강제 종료나 크래시 뒤에도 다시 열 수 있어요.

## 직접 만든 에이전트나 도구 등록하기

Vim이나 직접 만든 도구에는 세션 시작 훅이 없어요. 그래서 [동작 순서](#어떻게-동작하나요)의 2번을 프로그램이 직접 해요. 시작할 때 "나를 다시 열려면 이 명령을 실행하면 돼"라고 적어 두면, 3~5번은 AI 에이전트와 똑같이 흘러가서 재시작한 뒤 그 명령이 같은 패널에 입력돼요. 적어 두는 방법은 이 한 줄이에요.

```sh
rex do agent_resume_hint 'argv=["my-agent","--session","abc123"]'
```

- `argv`에는 다시 열 명령을 단어 단위로 나눠 적어요. 파일 경로는 절대 경로로 적으세요.
- 이 줄은 **그 프로그램이 직접** 실행해야 해요. 셸 프롬프트에서 치면 등록할 프로그램이 없어서 실패해요.
- 세션이 바뀌면 다시 실행하세요. 마지막에 등록한 명령이 남아요.

**예: Vim.** `~/.vimrc`에 아래를 넣으면, Vim을 켤 때마다 지금 연 파일들을 등록해요. 재시작한 뒤 같은 패널에서 `vim /절대경로/파일`이 다시 실행돼요.

```vim
if !empty($REX_BLOCK)
  autocmd VimEnter * call system('rex do agent_resume_hint --args ' . shellescape(json_encode({'argv': ['vim'] + map(argv(), {_, f -> fnamemodify(f, ':p')})})))
endif
```

Vim을 켤 때 연 파일만 다시 열어요. 나중에 `:e`로 연 파일, 커서 위치, 창 분할은 돌아오지 않아요.

**예: 직접 만든 에이전트.** 세션을 만들거나 바꿀 때 위 명령을 실행하게 하세요. Node.js라면 이렇게 할 수 있어요.

```js
import { execFile } from "node:child_process";

if (process.env.REX_BLOCK) {
  execFile("rex", ["do", "agent_resume_hint", "--args", JSON.stringify({ argv: ["my-agent", "--session", sessionId] })]);
}
```

`REX_BLOCK`은 Rex 패널 안에서만 있는 변수라서, Rex 밖에서는 아무것도 하지 않아요.

## 제한사항

**다시 열지 않는 경우**

- **`--restore=false`로 띄운 서버.** Rex가 패널을 되살리지 않으니 rex-agent-resume도 아무것도 하지 않아요. API 리비전이 8보다 낮은 Rex도 마찬가지예요.
- **API 리비전 8 미만의 Rex에서 업데이트한 직후의 첫 재시작.** 그 서버는 패널을 저장하지 않아서 패널이 돌아오지 않아요. 그다음 재시작부터 동작해요.
- **vi 명령 모드에 있는 셸 프롬프트.** 재개 명령이 실행되지 않아서 에이전트가 다시 열리지 않아요.
- **`--no-daemon` 없이 실행한 Codex.** Codex 세션은 `codex --no-daemon`으로 실행했을 때만 다시 열려요. 그냥 실행하면 Codex가 세션을 패널 밖의 공용 백그라운드 서버에서 돌려서, 그 세션을 기억하지 못해요.
- **서버가 꺼질 때 앞에 없던 프로그램.** 에이전트를 끄고 셸로 돌아와 있었다면 다시 열지 않아요.
- **대화가 시작되지 않은 세션.** 메시지를 하나도 보내지 않아 대화 기록이 없는 Claude Code나 Codex 세션은 열어도 "대화를 찾을 수 없다"가 나오므로 건너뛰어요.
- **오래된 기록.** 서버가 시작된 지 2분 안에만 다시 열어요. 마지막 기록이 3일보다 오래됐으면 다시 열지 않아요.

**기억하는 범위**

- **패널마다 마지막 하나만 기억해요.** 같은 패널에서 새 대화를 시작하거나 다른 세션으로 바꾸면 이전 기록은 덮어써져요. 이전 대화는 에이전트의 재개 목록(예: `claude --resume`)에서 직접 여세요.
- **설치 전부터 돌던 에이전트.** Claude Code와 명령줄에 세션 ID가 보이는 에이전트는 바로 기억해요. 나머지는 설치한 뒤 한 번 다시 시작하세요.
- **짧은 사각지대.** 에이전트의 훅이 실행되기 전이나 실행된 직후에 서버가 죽으면 그 에이전트는 기억하지 못해요. 에이전트를 끄고 약 2초 안에 서버가 죽으면 끈 에이전트가 다시 열려요.
- **화면 상태는 돌아오지 않아요.** 스크롤백, 커서 위치, 입력 중이던 내용은 되살리지 않아요.
- **에이전트가 다시 열리기 전에 친 글자.** 그 전에 패널에 친 글자는 지워져요. zsh와 bash에서는 Ctrl-Y로 되살릴 수 있어요. 공백으로 시작하는 명령을 히스토리에 남기지 않는 셸이라면, 재개 명령도 히스토리에 남지 않아요.

**환경**

- **Rex는 앱에서, Linux에서는 서비스로 시작하세요.** Claude Code나 Codex 안에서 띄운 Rex 서버는 그 에이전트의 환경 변수를 모든 패널에 물려줘요. 그러면 Claude Code가 대화 기록을 저장하지 않아요. 다시 여는 에이전트는 그 변수를 빼고 띄우지만, 직접 띄우는 에이전트는 영향을 받아요.
- **같은 기기의 서버만.** 원격 Rex 호스트에서 쓰려면 그 호스트에 rex-agent-resume을 설치하세요.

## 제거

명령 팔레트에서 **Uninstall rex-agent-resume**을 실행하거나, 이 명령을 실행하세요.

```sh
curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh -s uninstall
```

이 명령은 `~/.local/share/rex-agent-resume`까지 지워요.

## 크레딧

에이전트별 재개 명령, 훅과 플러그인 규칙, 프로세스 판별, 설치 위치는 [herdr](https://github.com/herdrdev/herdr) v0.9.5에서 옮겨 왔어요. herdr는 Apache License 2.0을 따라요.
