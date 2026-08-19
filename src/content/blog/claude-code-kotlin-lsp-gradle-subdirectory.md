---
title: 'Claude Code에서 Kotlin LSP가 참조를 못 찾을 때: Gradle 프로젝트 루트 확인하기'
description: 'Kotlin LSP 프로세스가 실행 중이어도 Gradle 프로젝트 루트가 틀리면 findReferences가 다른 파일의 사용처는 찾지 못하고 선언 위치만 반환할 수 있습니다. 서브디렉토리 프로젝트에서 원인을 구분하고 workspaceFolder로 교정하는 방법을 정리합니다.'
pubDate: 'Aug 5 2026'
tags: ['Claude Code', 'Kotlin', 'LSP', 'Gradle', '플러그인']
category: 'devtools'
draft: false
---

Claude가 Kotlin 코드를 찾을 때마다 grep 결과와 여러 파일을 읽으면 컨텍스트가 커집니다. LSP(Language Server Protocol)는 편집기 같은 개발 도구가 언어 서버에 정의 위치나 참조 목록을 물어보는 표준입니다. LSP로 정의와 참조를 바로 찾으면 필요한 코드만 읽게 할 수 있다고 봤습니다. 그래서 Kotlin LSP를 어떻게든 제대로 동작하게 만들고 싶었습니다.

Kotlin LSP 바이너리를 설치하고 Claude Code 플러그인도 활성화했습니다. 그런데 `findReferences`는 선언 위치 한 곳만 반환했습니다. 다른 파일에도 사용처가 있었지만 결과에 나오지 않았습니다.

> 2026년 7월 기준입니다. Claude Code 플러그인 설정과 Kotlin LSP는 빠르게 바뀌고 있습니다. 특히 Kotlin LSP는 현재 Alpha 상태입니다. 이 글과 현재 공식 문서가 다르면 공식 문서 쪽이 맞습니다.

## 왜 LSP의 참조 검색이 코드의 선언 위치만 반환할까?

실무 환경에서 프론트엔드와 백엔드, 문서 레포지토리를 Git 서브모듈로 묶은 상위 Git 레포지토리에서 작업하고 있었습니다. Claude Code는 모든 서브모듈을 함께 다룰 수 있도록 상위 레포지토리 루트에서 실행했습니다. Kotlin 코드를 다룰 때 grep과 파일 읽기를 반복하지 않도록 `kotlin-lsp` 바이너리를 설치하고 공식 플러그인을 활성화했습니다.

플러그인을 적용한 뒤 Kotlin 파일의 심볼 목록은 읽을 수 있었습니다. 언어 서버 프로세스도 실행 중이었습니다. 그러나 다른 파일에서 여러 번 사용하는 클래스로 `findReferences`를 실행하자 클래스가 선언된 위치 한 곳만 반환했습니다. grep으로 확인한 사용처는 여러 파일에 남아 있었습니다.

언어 서버가 아예 실행되지 않은 상태와는 달랐습니다. 현재 파일은 해석하지만 다른 파일과의 관계는 찾지 못했습니다. 프로세스 실행 여부만 확인해서는 원인을 알 수 없었습니다. 프로젝트 모델과 인덱스가 만들어졌는지 따로 확인해야 했습니다.

## LSP는 실행됐으니 인덱싱을 의심함

LSP는 클라이언트와 서버로 나뉩니다. Claude Code가 클라이언트이고, `kotlin-lsp`가 Kotlin 코드를 해석하는 서버입니다. 둘은 JSON-RPC 메시지를 주고받습니다.

Claude Code에서 Kotlin 코드 탐색이 동작하려면 세 가지가 모두 갖춰져야 합니다.

| 구성 요소 | 역할 | 실패했을 때 |
| --- | --- | --- |
| 언어 서버 바이너리 | Kotlin 코드를 분석하는 프로세스 | 서버를 실행하지 못한다 |
| Claude Code LSP 플러그인 | `.kt`, `.kts` 파일을 언어 서버에 연결한다 | Claude Code가 서버를 호출하지 않는다 |
| 프로젝트 모델과 인덱스 | Gradle 설정, 모듈, 소스 경로, 의존성을 해석한다 | 현재 파일은 읽어도 크로스파일 참조를 찾지 못한다 |

세 번째 요소인 프로젝트 모델과 인덱스는 언어 서버가 직접 만듭니다. `kotlin-lsp`는 프로젝트를 열 때 Gradle을 실행해(Gradle import) 모듈 구성, 소스 경로, 의존성 classpath를 읽습니다. 이 정보가 있어야 한 파일을 넘어 다른 파일과 외부 라이브러리의 심볼까지 연결할 수 있습니다.

Claude Code에서 심볼 목록은 읽혔고 `findReferences`도 선언 위치 한 곳은 응답으로 돌려줬습니다. 서버가 응답했으니 바이너리는 실행됐고 Claude Code가 그 응답을 받아 썼으니 플러그인 연결까지는 동작한 것입니다. 하지만 그것만으로 Gradle import가 끝나 크로스파일 인덱스까지 만들어졌다고 볼 수는 없습니다.

이때 현재 열어 둔 파일 안의 클래스 선언은 해석할 수 있습니다. 그래서 `findReferences` 결과가 완전히 비지 않고 선언 위치 한 곳만 나옵니다. 검색이 성공한 것처럼 보이지만 실제로는 다른 파일의 사용처를 찾는 인덱스가 없는 상태입니다.

## 언어 서버는 루트에서 빌드 파일을 못 찾으면 크로스파일 인덱스를 못 만듦

kotlin-lsp는 JVM 프로젝트에서 [Gradle과 Maven 빌드 시스템을 지원합니다](https://github.com/Kotlin/kotlin-lsp). 모듈 구성과 의존성 classpath를 이 빌드에서 읽어 프로젝트 모델을 만들기 때문에, 루트에서 빌드 파일을 찾지 못하면 그 모델을 만들 수 없습니다.

그 레포지토리의 구조는 다음과 같았습니다.

```text
workspace/
├── backend/
│   ├── build.gradle.kts
│   └── src/
├── frontend/
└── documents/
```

Claude Code는 `workspace/`에서 실행했습니다. 여러 프로젝트를 함께 수정하려면 이 위치가 편합니다. 그러나 실제 Kotlin 프로젝트의 Gradle 설정은 `backend/`에만 있었습니다.

언어 서버가 `workspace/`를 프로젝트 루트로 열면 그 위치에서 `settings.gradle.kts`, `settings.gradle`, `build.gradle.kts`, `build.gradle`을 찾지 못합니다. 조사 당시 kotlin-lsp 로그에는 다음 메시지가 남았습니다.

```text
No applicable build tools found for .../workspace
```

반면 `backend/`를 루트로 전달하자 `No applicable build tools` 메시지가 사라지고 Gradle이 모듈을 읽는 로그로 이어졌습니다. 모듈과 소스 경로, 의존성 classpath를 얻은 뒤에는 다른 파일의 사용처까지 검색할 수 있었습니다.

## `backend/`를 루트로 주면 참조가 살아남

설정을 만들기 전에 가장 단순한 대조군부터 확인할 수 있습니다.

```bash
cd backend
claude
```

이 상태에서 같은 심볼의 `findReferences`가 여러 파일을 반환한다면 Kotlin 코드나 언어 서버 설치보다 프로젝트 루트가 원인일 가능성이 큽니다. 워크스페이스 루트에서 실행했을 때와 달라지는 핵심 조건이 Gradle 프로젝트 위치이기 때문입니다.

다만 이 방법을 영구 해결책으로 쓰면 프론트엔드와 다른 하위 프로젝트를 한 세션에서 다루기 불편합니다. 목표는 Claude Code를 `workspace/`에서 실행하되 Kotlin 언어 서버만 `backend/`를 열게 하는 것입니다.

## 같은 서버가 Neovim에서는 정상 동작함

문제가 서버 쪽인지 클라이언트의 루트 선택 쪽인지 확인하기 위해, 같은 `kotlin-lsp` 바이너리와 JDK로 Neovim에서도 시험했습니다. 워크스페이스 루트에서 Neovim을 실행한 뒤 `backend/`의 Kotlin 파일을 열자, 언어 서버는 `backend/`를 프로젝트 루트로 선택했습니다. 참조 검색 결과는 Claude Code에서 루트를 교정한 결과와 같았습니다.

차이는 언어 서버가 아니라 클라이언트의 루트 선택 방식이었습니다. nvim-lspconfig의 현재 `kotlin_lsp` 설정에는 다음 파일들이 root marker로 등록되어 있습니다.

- `settings.gradle`, `settings.gradle.kts`
- `build.gradle`, `build.gradle.kts`
- `pom.xml`
- `workspace.json`

Neovim은 연 Kotlin 파일에서 상위 디렉토리로 올라가며 marker를 찾습니다. `backend/src/...`의 파일을 열면 `backend/settings.gradle.kts`를 만나 그 위치를 루트로 잡습니다. Claude Code에서 잘못된 루트를 보냈을 때와 달리 별도 프록시가 필요하지 않았습니다.

이 비교는 kotlin-lsp 자체나 저장된 인덱스가 망가졌다는 가능성을 줄였습니다. 같은 서버와 실행 환경에서 클라이언트가 전달한 루트만 달랐고 올바른 루트를 선택한 두 클라이언트의 참조 결과가 일치했습니다.

## `initialize.rootUri`를 고치는 프록시로 원인을 확인함

실측 당시에는 LSP 루트를 지정하는 공식 설정을 찾지 못했습니다. 그래서 Claude Code와 kotlin-lsp 사이에 stdio 프록시를 두었습니다.

LSP 메시지는 헤더와 JSON 본문으로 구성됩니다.

```text
Content-Length: 123

{"jsonrpc":"2.0","method":"initialize",...}
```

프록시는 클라이언트에서 서버로 가는 메시지 가운데 `initialize` 요청만 열어 봅니다. `rootUri`, `rootPath`, `workspaceFolders`를 Gradle 프로젝트 경로로 바꾸고 나머지 메시지는 그대로 전달합니다.

```python
def rewrite_initialize(params, gradle_root):
    new_uri = path_to_uri(gradle_root)

    if params.get("rootUri") is not None:
        params["rootUri"] = new_uri
    if params.get("rootPath") is not None:
        params["rootPath"] = gradle_root
    if isinstance(params.get("workspaceFolders"), list):
        params["workspaceFolders"] = [
            {"uri": new_uri, "name": os.path.basename(gradle_root)}
        ]

    return params
```

이 방법은 문제의 원인을 확인하는 데 유용했습니다. Claude Code가 워크스페이스 루트를 보낸 상태에서 프록시가 `backend/`로 교정하자, `backend/`를 직접 루트로 보낸 대조 실험과 같은 참조 결과가 나왔습니다.

## 루트 말고 JDK도 맞아야 함

프로젝트 루트와 JDK는 따로 확인해야 합니다. 실측한 프로젝트는 Gradle 7.6.4와 JDK 17을 사용했습니다. `backend/`를 올바른 루트로 전달해도 JDK 11 환경에서는 Gradle import가 `ScriptCompilationException`으로 실패했습니다. JDK 17을 주입하자 같은 루트에서 참조 검색이 정상화됐습니다.

kotlin-lsp 실행 파일에 런타임이 포함되어 있다는 사실과 Gradle이 프로젝트 모델을 만들 때 사용하는 JDK는 같은 문제가 아닙니다. 서버 프로세스가 시작됐더라도 프로젝트 빌드가 요구하는 JDK로 Gradle import에 성공해야 classpath와 모듈 정보를 얻을 수 있습니다.

Neovim에서도 같은 조건을 확인했습니다. 루트 marker는 `backend/`를 올바르게 찾았지만 셸 환경의 JDK가 11이면 import가 실패했습니다. kotlin-lsp 바이너리와 JDK 17을 명시하자 Claude Code와 같은 결과를 반환했습니다.

## 루트를 교정하자 선언 1곳이 참조 47건으로 늘어남

첫 번째 레포지토리에서는 워크스페이스 루트를 그대로 보낸 대조군이 선언 위치 한 곳만 반환했습니다. `backend/`를 직접 전달하거나 프록시가 같은 경로로 교정했을 때는 6개 파일에서 47건을 반환했습니다.

두 번째 레포지토리에서도 같은 구조를 재현했습니다. 루트에는 Gradle 설정이 없고 `backend/build.gradle.kts`만 있었습니다. 첫 호출은 선언 위치 한 곳뿐이었지만 초기 인덱싱이 끝난 뒤 3개 파일에서 8건을 반환했습니다. grep으로 센 기대값도 8건이었습니다.

| 환경 | 루트 상태 | 결과 |
| --- | --- | --- |
| 첫 번째 레포지토리 대조군 | 워크스페이스 루트, Gradle 설정 없음 | 선언 위치 1곳 |
| 첫 번째 레포지토리 교정 후 | `backend/`를 루트로 전달 | 47건, 6파일 |
| 두 번째 레포지토리 첫 호출 | `backend/` 교정, 인덱싱 중 | 선언 위치 1곳 |
| 두 번째 레포지토리 워밍업 후 | `backend/` 교정, 인덱싱 완료 | 8건, 3파일 |

두 실험이 보여주는 것은 `workspaceFolder` 필드의 구현이 아니라 **Gradle 프로젝트 루트를 올바르게 전달하면 크로스파일 인덱싱이 정상화된다**는 점입니다.

## 코드의 선언 위치만 나오면 루트, JDK, 인덱싱을 의심한다

당연하지만 결과에 선언 위치 한 곳만 나온다는 것은 증상일 뿐, 그 자체로 프로젝트 루트가 틀렸다는 뜻은 아닙니다. JDK나 빌드 설정이 맞지 않거나 초기 Gradle sync와 인덱싱이 진행 중이어도 같은 결과가 나올 수 있습니다.

세 경우는 로그와 시간 경과로 구분할 수 있습니다.

| 상태 | 로그와 동작 |
| --- | --- |
| 프로젝트 루트가 틀림 | `No applicable build tools`가 나오고 기다려도 크로스파일 결과가 생기지 않는다 |
| JDK 또는 빌드 설정이 틀림 | Gradle import를 시도하지만 스크립트 컴파일이나 빌드 모델 생성이 실패한다 |
| 초기 인덱싱 중 | Gradle import가 시작되고, 시간이 지난 뒤 같은 요청의 결과가 늘어난다 |

두 번째 레포지토리의 첫 호출이 선언 위치만 반환한 이유는 잘못된 루트가 아니라 워밍업이었습니다. grep 결과로 실제 사용처가 있다는 것을 확인한 뒤 다시 요청하자 8건이 나왔습니다.

따라서 검증 순서는 다음이 안전합니다.

1. Gradle 프로젝트 경로를 확인합니다.
2. 프로젝트가 요구하는 JDK와 언어 서버 프로세스의 `JAVA_HOME`을 맞춥니다.
3. 언어 서버 로그에서 빌드 도구 감지와 Gradle import 여부를 확인합니다.
4. 초기 인덱싱이 끝날 시간을 둡니다.
5. `findReferences`를 다시 실행합니다.
6. 알려진 심볼 하나는 grep 결과와 교차 확인합니다.

## 루트를 바로잡으니 읽는 양이 줄어듦

애초에 Kotlin LSP를 붙이려던 이유는 grep 결과와 여러 파일을 통째로 읽는 대신 필요한 코드만 읽게 하려는 것이었습니다. 루트를 교정해 참조 검색이 동작하는 상태에서, 참조를 한 번 확인하는 데 실제로 읽는 양을 재봤습니다.

한 레포지토리에서 심볼 몇 개의 참조를 확인하는 작업이었습니다. `findReferences`와 `documentSymbol` 응답을 합치면 약 130라인이었습니다. 같은 판단을 언어 서버 없이 하려면 후보 파일 7개를 통째로 읽어야 했고 그 파일들은 합쳐서 8,699라인이었습니다. 응답으로 확인한 양이 통독보다 약 98% 적었습니다.

정확도도 달랐습니다. 같은 심볼을 grep으로 찾으면 15건이 나왔는데, 그중 7건은 이름만 같은 다른 대상이었습니다. 다른 클래스의 동명 메서드가 문자열로 걸린 것입니다. `findReferences`는 심볼을 기준으로 하므로 이 오탐이 섞이지 않았습니다.

이 수치는 파일 크기와 심볼 사용 빈도에 따라 달라집니다. 다만 방향은 분명합니다. 참조가 여러 파일에 흩어져 있을수록, 통독 대신 언어 서버 응답만 읽는 편이 읽는 양과 오탐을 함께 줄입니다.

다만 언어 서버 응답도 완벽하진 않습니다. 인덱싱이 끝나기 전에는 결과가 불완전하고 리플렉션이나 문자열로 참조하는 코드는 잡지 못합니다. 알려진 심볼 하나를 grep과 교차 확인해야 하는 이유입니다.
## 프록시를 workspaceFolder로 바꿔 개선함

프록시로 원인을 확인한 뒤, 프록시를 걷어내고 `workspaceFolder` 설정으로 바꿨습니다. 그리고 kotlin-lsp를 그 서브디렉토리 루트로 실행해 참조 검색이 실제로 되는지 확인했습니다. 첫 호출은 선언 한 곳만 나왔고 인덱싱이 끝난 뒤 약 40초가 지나자 같은 심볼이 세 파일에서 여섯 건으로 늘어났습니다. 앞서 본 워밍업이 그대로 재현됐습니다.

프록시가 하던 두 가지는 `workspaceFolder`가 대신하지 못했습니다. 프록시는 Gradle 마커를 스캔해 서브디렉토리를 알아서 찾고 JDK를 주입했지만 `workspaceFolder`는 경로를 고정하고 JDK는 셸에서 맞춰야 합니다. 그래서 서브디렉토리가 레포마다 다르거나 JDK를 자동으로 맞춰야 하면 프록시가 여전히 대안입니다.

자기 환경에서 쓸 때는 서브디렉토리 경로와 JDK를 맞춘 뒤, 알려진 심볼로 참조가 되살아나는지 한 번 확인하는 것이 안전합니다.

## `workspaceFolder` 설정하는 법

위에서 바꾼 `workspaceFolder` 설정을 자세히 보면 이렇습니다. Claude Code의 현재 플러그인 레퍼런스는 LSP 서버 설정의 선택 필드로 `workspaceFolder`를 문서화하고 있습니다. LSP 설정에서는 `${CLAUDE_PROJECT_DIR}` 변수도 사용할 수 있습니다.

프로젝트 안에 최소한의 커스텀 플러그인을 둔다고 가정합니다.

```text
.claude/plugins/kotlin-lsp-backend/
├── .claude-plugin/
│   └── plugin.json
└── .lsp.json
```

매니페스트에는 플러그인 정보만 둡니다.

```json
{
  "name": "kotlin-lsp-backend",
  "version": "1.0.0",
  "description": "Kotlin LSP for the backend Gradle project"
}
```

핵심은 `.lsp.json`의 `workspaceFolder`입니다.

```json
{
  "kotlin-lsp-backend": {
    "command": "kotlin-lsp",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".kt": "kotlin",
      ".kts": "kotlin"
    },
    "workspaceFolder": "${CLAUDE_PROJECT_DIR}/backend",
    "startupTimeout": 120000
  }
}
```

`CLAUDE_PROJECT_DIR`는 Claude Code를 실행한 프로젝트 루트입니다. 위 설정에서는 세션의 기준 디렉토리를 `workspace/`로 유지하면서 Kotlin LSP의 워크스페이스만 `workspace/backend/`로 지정합니다.

Claude Code가 LSP 설정에서 치환하는 변수는 `${CLAUDE_PROJECT_DIR}`와 플러그인 경로 변수(`${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`)입니다. `${KOTLIN_LSP_JAVA_HOME}` 같은 임의 환경변수의 확장은 보장되지 않으므로, JDK는 `env` 값의 치환에 기대지 말고 Claude Code를 실행하는 셸에서 `JAVA_HOME`으로 지정합니다. LSP 서버 프로세스가 그 환경을 물려받습니다.

macOS에서 JDK 17 프로젝트라면 세션을 시작하기 전에 `JAVA_HOME`을 지정합니다.

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

로컬 플러그인을 시험할 때는 `--plugin-dir`로 시작할 수 있습니다.

```bash
claude --plugin-dir ./.claude/plugins/kotlin-lsp-backend
```

공식 Kotlin LSP 플러그인이 같은 `.kt` 확장자를 담당하고 있다면 두 서버가 충돌하지 않도록 하나만 활성화해야 합니다. 커스텀 플러그인을 쓰는 동안에는 공식 플러그인을 비활성화합니다.

```bash
claude plugin disable kotlin-lsp@claude-plugins-official
```

세션 중에 플러그인을 설치하거나 설정을 바꿨다면 Claude Code 안에서 `/reload-plugins`를 실행할 수 있습니다. 이 명령은 플러그인과 LSP 서버를 다시 로드합니다. `claude plugin` CLI의 서브커맨드가 아니라 실행 중인 세션의 슬래시 커맨드입니다.

지속적으로 사용하거나 팀에 배포하려면 로컬 마켓플레이스 또는 프로젝트 범위 플러그인으로 설치할 수 있습니다. 설치 방식과 관계없이 해결의 핵심은 `workspaceFolder`가 Gradle 프로젝트를 가리키는지입니다.

> 이 설정 예시는 현재 공식 스키마를 바탕으로 정리했습니다. 원래 조사 때는 이 설정을 찾지 못해 프록시로 루트를 교정했습니다.

## Kotlin LSP 자체의 한계

프로젝트 루트를 바로잡아도 모든 문제가 해결되는 것은 아닙니다. JetBrains의 kotlin-lsp 레포지토리는 프로젝트 상태를 Alpha로 표시하고 있습니다. Gradle과 Maven을 지원하지만 서버 안정성과 기능 완성도는 계속 바뀔 수 있습니다.

Gradle import는 프로젝트의 JDK와 빌드 스크립트에도 영향을 받습니다. 루트를 찾은 뒤 import가 실패한다면 `JAVA_HOME`, Gradle wrapper, Kotlin과 Java 버전, 빌드 스크립트 오류를 별도로 확인해야 합니다. `No applicable build tools`와 Gradle 실행 중 발생한 오류는 원인이 다릅니다.

새 clone이나 worktree에서는 경로가 달라져 초기 인덱싱을 다시 기다릴 수 있습니다. 작업용 맥에서는 같은 레포지토리를 일곱 곳이 넘는 로컬 경로에 두고 쓰고 있었습니다. kotlin-lsp 인덱스는 프로젝트 경로별 디렉토리에 저장되므로, 서로 다른 경로의 인덱스 11개가 30GB 넘게 쌓여 있었습니다. 이 수치는 프로젝트마다 달라지지만 짧게 쓰고 버리는 worktree가 많다면 초기 인덱싱 시간과 디스크 사용량을 함께 봐야 합니다.

그렇다고 worktree 사용 자체를 피할 필요는 없습니다. 사람이 worktree마다 별도 Claude Code 세션을 오래 사용하는 경우에는 각 인덱스의 비용을 회수할 수 있습니다. 수명이 짧은 서브에이전트용 임시 worktree처럼, 인덱스를 만든 직후 작업이 끝나는 경우에 부담이 더 큽니다. `/reload-plugins`는 현재 세션의 LSP를 다시 시작할 뿐, 다른 worktree의 인덱스를 공유하게 만들지는 않습니다.

참조 검색 결과가 적을 때는 곧바로 "사용처가 없다"고 결론 내리지 말고 인덱싱 상태를 먼저 확인해야 합니다.

## 결론

LSP 프로세스가 떠 있다는 사실만으로 크로스파일 탐색이 준비된 것은 아닙니다. Kotlin 언어 서버가 Gradle 프로젝트 모델을 만들고 인덱싱을 마쳐야 `findReferences`가 의미 있는 결과를 돌려줍니다.

루트에 Gradle 설정이 없고 실제 프로젝트가 하위 디렉토리에 있다면, 먼저 그 경로를 의심해야 합니다. 현재 Claude Code에서는 커스텀 LSP 설정의 `workspaceFolder`로 이 차이를 표현할 수 있습니다.

## 부록: 언어 서버 로그 보는 법

본문에서 "언어 서버 로그를 확인한다"고 한 로그는 다음에서 봅니다.

`kotlin-lsp`는 로그를 stderr로 내보냅니다. 로그 레벨은 실행 인자로 올립니다.

```bash
kotlin-lsp --stdio --log-level DEBUG
```

`--log-level`은 TRACE, DEBUG, INFO, WARNING, ERROR를 받습니다. 캐시와 인덱스 경로는 `--system-path`로 지정합니다.

Neovim에서는 `:LspLog`가 로그 파일을 엽니다. 기본 경로는 `~/.local/state/nvim/lsp.log`입니다. `No applicable build tools`나 Gradle import 진행 메시지가 여기에 남습니다. 더 자세히 보려면 세션에서 로그 레벨을 올립니다.

```lua
vim.lsp.set_log_level("debug")
```

Neovim에서 어떤 루트가 선택됐는지는 `:LspInfo`의 `root_dir`로 확인합니다. 그 값이 `initialize` 요청의 `rootUri`로 서버에 전달됩니다.

이 글의 Claude Code 설정에서는 stdio 프록시가 `initialize` 메시지와 교정한 루트를 파일로 기록했고 kotlin-lsp의 stderr는 프록시를 거쳐 전달됐습니다. 그래서 프록시 로그가 루트 교정 여부를 확인하는 지점이었습니다.

## 참고 문헌

- [Claude Code Plugins reference](https://code.claude.com/docs/en/plugins-reference): LSP 플러그인의 `.lsp.json` 형식, `workspaceFolder`, `env`, `initializationOptions`, `${CLAUDE_PROJECT_DIR}`, `--plugin-dir` 동작.
- [Kotlin Language Server](https://github.com/Kotlin/kotlin-lsp): Homebrew 설치, Gradle과 Maven 지원 기능과 Alpha 상태.
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/): 개발 도구와 언어 서버가 JSON-RPC로 코드 탐색 기능을 주고받는 구조.
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig): 파일에서 상위 디렉토리의 root marker를 찾아 LSP 워크스페이스를 정하는 방식과 Kotlin LSP 기본 marker.
- [별도 레포지토리 적용 기록 gist](https://gist.github.com/Uginim/bc0d046e517bc28e957fc7d4276117f5): 본문의 프록시를 다른 레포지토리에 적용해 워밍업 후 8건, 3파일을 확인한 기록.

<!-- HUMANIZE-SUMMARY v1.6.1
run_id: 2026-08-06-001
route: light (conservative)
metrics:
  char_in: 13090
  char_out: 13078
  change_rate: 0.09%
  self_check: 6/6
  grade: A
categories:  # before → after
  C-11 연결어미(-고/-지만) 직후 쉼표: 12 → 0
self_check:
  - 고유명사/수치/인용/코드/표 100% 보존: OK
  - 변경률 30% 이하 (0.09%): OK
  - 장르 이탈 없음 (기술 블로그 유지): OK
  - register 보존 (격식체 ~합니다/~됩니다 그대로): OK
  - S1 잔존 0건 (C-11 canonical set 모두 제거): OK
  - 인공 표현 추가 없음 (쉼표 삭제만, 어휘/구조 무변경): OK
highlights:
  - id: C-11
    before: "서버가 응답했으니 바이너리는 실행됐고, Claude Code가 그 응답을 받아 썼으니"
    after: "서버가 응답했으니 바이너리는 실행됐고 Claude Code가 그 응답을 받아 썼으니"
  - id: C-11
    before: "검색이 성공한 것처럼 보이지만, 실제로는 다른 파일의 사용처를 찾는 인덱스가 없는 상태입니다."
    after: "검색이 성공한 것처럼 보이지만 실제로는 다른 파일의 사용처를 찾는 인덱스가 없는 상태입니다."
  - id: C-11
    before: "루트 marker는 backend/를 올바르게 찾았지만, 셸 환경의 JDK가 11이면 import가 실패했습니다."
    after: "루트 marker는 backend/를 올바르게 찾았지만 셸 환경의 JDK가 11이면 import가 실패했습니다."
residual_findings: >
  의도적 보류(보수 강도). 다음은 C-11 canonical set(-고/-며/-면서/-지만/-아서/-어서) 밖이라 손대지 않음:
  '위해,' '열자,' '교정하자,' '때문에,' '-므로,' '증상일 뿐,' 등 (자연스러운 국어 쉼표로 판단).
  A-18 좌향 관형절 8건, lexical_diversity 낮음은 기술 주제 특성상 의미/정확도 훼손 위험으로 보존.
grade_reason: "A. 유일하게 flagged된 S1 패턴(C-11) 12건 전부 제거, 변경률 0.09%, 자체검증 6항 통과. 격식체/코드/표/수치 무변경."
-->
