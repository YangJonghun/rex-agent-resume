<p align="center">
  <a href="README.md">English</a> · 한국어
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-666666?labelColor=333333" alt="Platform: macOS" />
</p>

# rex-agent-resume

> [!WARNING]
> Rex는 아직 베타예요. 서버 API, Lua 런타임, 복원 동작이 어느 릴리스에서든 바뀔 수 있어서, Rex를 업데이트한 뒤 rex-agent-resume이 예고 없이 동작하지 않을 수 있어요.

[Rex](https://www.superlogical.com/rex) 서버가 다시 시작되면 Rex는 세션, 창, 패널을 되살리지만, 패널은 모두 빈 셸로 돌아와요. 그 안에서 돌던 프로그램은 사라져요.

rex-agent-resume은 패널마다 무엇이 돌고 있었는지 기억해 뒀다가, 재시작한 뒤 같은 패널에서 다시 실행해요.

- **AI 코딩 에이전트:** Claude Code, Codex 등 18종은 설치만 하면 보던 대화로 다시 열려요.
- **직접 만든 에이전트나 도구:** Vim처럼 다른 프로그램도 "다시 여는 명령"을 한 번 등록해 두면 같이 다시 열려요.

## 시작하기

1. Rex 버전을 확인하세요. 세션 복원이 들어간 ge6592f(2026-10-30) 이상이어야 하고, 이 명령이 `8` 이상을 보여야 해요.

   ```sh
   rex api call server.status | jq .api_revision
   ```

2. 설치하세요. 설치된 에이전트를 찾아 연결하고, Rex에도 연결해요.

   ```sh
   curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh
   ```

3. 끝이에요. 평소처럼 Rex 패널에서 에이전트를 쓰면 돼요.

같은 명령을 다시 실행하면 최신 버전으로 업데이트돼요. 특정 [릴리스](https://github.com/YangJonghun/rex-agent-resume/releases)를 설치하려면 버전을 지정하세요.

```sh
curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | REX_AGENT_RESUME_REF=v0.1.0-beta.1 sh
```

`jq`가 필요한데, macOS에는 `/usr/bin/jq`가 기본으로 있어요.

## 사용법

설치 시 자동으로 적용돼요. 단, 설치할 때 이미 실행되고 있던 세션에는 적용되지 않을 수 있어요. 그런 세션은 한 번 다시 시작하세요.

아래 액션으로 자동 재개를 끄거나, 에이전트에 넣은 훅과 플러그인을 제거할 수 있어요.

### 액션

⌘⇧P로 명령 팔레트를 열고 `Agent Resume`을 검색하세요. `rex do <이름>`으로도 실행할 수 있어요.

| 팔레트 제목                                                         | 이름                     | 하는 일                                     |
| ------------------------------------------------------------------- | ------------------------ | ------------------------------------------- |
| Turn Off Agent Resume on Startup / Turn On Agent Resume on Startup  | `agent_resume_toggle`    | 재시작할 때 자동으로 다시 여는 걸 끄거나 켜요 |
| Uninstall rex-agent-resume                                          | `agent_resume_uninstall` | 훅, 플러그인, Rex 설정을 빼요               |
| Register Resume Command for This Pane                               | `agent_resume_hint`      | 프로그램이 다시 여는 명령을 등록할 때 써요  |

자동 재개를 꺼 둔 상태에서 서버가 다시 시작됐다면, 토글로 다시 켤 때 바로 재개해요.

## 어떻게 동작하나요

Claude Code를 예로 들면 아래와 같은 순서로 동작해요.

1. **설치할 때.** Claude Code의 세션 시작 훅에 우리 스크립트(`rex-agent-resume-hook`)를 넣어요.
2. **대화를 시작하거나 바꿀 때.** Claude Code가 훅을 실행하면서 세션 ID를 넘겨요. 우리 스크립트는 "이 패널에는 `claude`, 세션은 `abc`"라고 적어 둬요. 새 대화로 바꾸면 덮어써요.
3. **켜져 있는 동안 계속.** Rex 서버 안에서 도는 감시자가 "지금 앞에 에이전트가 떠 있는 패널" 목록을 저장해요. 패널에 변화가 있으면 2초 뒤에, 아무 일이 없어도 5분마다 저장해요. 에이전트를 끄고 셸로 돌아온 패널은 목록에서 빠져요.
4. **서버가 꺼질 때.** 아무것도 하지 않아요. 3번에서 저장해 둔 목록이 남아 있어요.
5. **서버가 다시 켜질 때.** Rex가 패널을 빈 셸로 되살리면, 감시자가 저장해 둔 목록을 읽고 각 패널에 `claude --resume abc`를 대신 입력해요.

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
- **Rex를 업데이트한 직후의 첫 재시작.** 직전 서버가 패널을 저장하지 않아서 패널이 돌아오지 않아요. 그다음 재시작부터 동작해요.
- **서버가 꺼질 때 앞에 없던 프로그램.** 에이전트를 끄고 셸로 돌아와 있었다면 다시 열지 않아요.
- **대화가 시작되지 않은 세션.** 메시지를 하나도 보내지 않아 대화 기록이 없는 Claude Code나 Codex 세션은 열어도 "대화를 찾을 수 없다"가 나오므로 건너뛰어요.
- **오래된 기록.** 서버가 시작된 지 2분 안에만 다시 열어요. 마지막 기록이 3일보다 오래됐으면 다시 열지 않아요.

**기억하는 범위**

- **패널마다 마지막 하나만 기억해요.** 같은 패널에서 새 대화를 시작하거나 다른 세션으로 바꾸면 이전 기록은 덮어써져요. 이전 대화는 에이전트의 재개 목록(예: `claude --resume`)에서 직접 여세요.
- **설치 전부터 돌던 에이전트.** Claude Code와 명령줄에 세션 ID가 보이는 에이전트는 바로 기억해요. 나머지는 설치한 뒤 한 번 다시 시작하세요.
- **몇 초의 사각지대.** 에이전트를 시작하고 약 3초 안에 서버가 죽으면 기억하지 못해요. 에이전트를 끄고 약 2초 안에 죽으면 끈 에이전트가 다시 열려요.
- **화면 상태는 돌아오지 않아요.** 스크롤백, 커서 위치, 입력 중이던 내용은 되살리지 않아요.

**환경**

- **Rex는 앱에서 시작하세요.** Claude Code나 Codex 안에서 띄운 Rex 서버는 그 에이전트의 환경 변수를 모든 패널에 물려줘요. 그러면 Claude Code가 대화 기록을 저장하지 않아요. 다시 여는 에이전트는 그 변수를 빼고 띄우지만, 직접 띄우는 에이전트는 영향을 받아요.
- **로컬 서버만.** 원격 Rex 호스트의 패널은 다시 열지 않아요.

## 제거

명령 팔레트에서 **Uninstall rex-agent-resume**을 실행하거나, 이 명령을 실행하세요.

```sh
curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh -s uninstall
```

이 명령은 `~/.local/share/rex-agent-resume`까지 지워요.

## 크레딧

에이전트별 재개 명령, 훅과 플러그인 규칙, 프로세스 판별, 설치 위치는 [herdr](https://github.com/herdrdev/herdr) v0.9.5에서 옮겨 왔어요. herdr는 Apache License 2.0을 따라요.
