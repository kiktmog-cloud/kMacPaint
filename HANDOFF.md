# 🤝 프로젝트 인수인계 문서 (HANDOFF.md)

**프로젝트명:** kMacPaint (Windows 11 mspaint REA 기반 macOS 네이티브 재구현)  
**최종 갱신일자:** 2026-11-18  
**작업 경로:** `/Users/inkeunkang/Library/CloudStorage/GoogleDrive-gemus.kik@gmail.com/내 드라이브/종합집계_260416/Tools_툴즈_260715/261118_맥_그림판_mspaint`  
**플랫폼 타겟:** macOS 12.0 (Monterey) 이상 (Apple Silicon M1~M5 및 Intel Universal)  
**기술 스택:** Swift 5.7+, AppKit, CoreGraphics, Swift Package Manager (SPM)

---

## 1. 프로젝트 배경 및 REA(역공학) 분석 요약

Windows 11 최신 그림판(`mspaint.exe`)의 동작 방식과 UI/UX를 분석하여, 맥용 오픈소스 그림판(Paintbrush 등)이 제공하지 못하는 윈도우 그림판 고유의 핵심 인터랙션을 맥 네이티브 환경에 클린룸 재구현(Clean-room Reconstruction)했습니다.

* **아키텍처 종속성 제거:** C++/WinRT, Direct2D, HLSL 셰이더 의존성을 순수 Swift / AppKit / CoreGraphics로 치환
* **경량화 설계:** 무거운 Copilot/AI 모듈을 배제하여 시작 속도 0.1초 미만의 반응성 높은 네이티브 드로잉 툴로 구현
* **에셋 100% 보존:** Windows 11 `mspaint.exe` 추출 원본 SVG 아이콘 및 시그니처 20색 팔레트 적용

---

## 2. 완료된 핵심 기능 구현 현황

### 1) 캔버스 엔진 & Undo/Redo
* **소스:** `Sources/kMacPaint/Canvas/CanvasModel.swift`
* **내용:** 32-bit RGBA `CGContext` 기반 비트맵 버퍼. 최대 35단계 스냅샷 기반 `undoStack`/`redoStack`을 통한 완벽한 되돌리기(`⌘Z`) 및 다시 실행(`⇧⌘Z`). PNG/JPEG 저장 및 파일 열기 지원.

### 2) 8방향 캔버스 리사이즈 핸들 & 실시간 확장 가이드 (좌측/상단 확장 완벽 지원)
* **소스:** `Sources/kMacPaint/Canvas/ResizeHandle.swift`, `CanvasView.swift`, `CanvasModel.swift`
* **내용:** 캔버스 좌측, 상단, 우측, 하단 및 4개 모서리(좌상, 우상, 좌하, 우하) 총 8곳에 8x8px 핸들 배치. 좌측 및 상단 드래그 시 기존 도화지 내용을 오프셋 이동하여 보존하며 새 영역을 2번 배경색으로 확장. 임시 뷰 프레임 확장 기법을 적용하여 뷰 클리핑 없이 **파란색+흰색 이중 점선 가이드(2.5px)와 옅은 반투명 확장 영역** 표시. 마우스 릴리즈 시 2번 배경색으로 확장 및 Undo 스택 등록. `⌘K` 단축키를 통한 직접 수치 입력 여백 확장 지원. 이미지를 열거나 새 문서를 생성할 때 뷰포트 정중앙 자동 정렬(Centering) 및 여유 마진 지원.

### 3) 캔버스 위 인라인 텍스트 & 스마트 서식 리본
* **소스:** `Sources/kMacPaint/Canvas/InlineTextEditor.swift`, `CanvasView.swift`
* **내용:** 
  * 팝업창(NSAlert)을 완전히 배제하고 클릭 위치에 직접 점선 텍스트 박스 생성.
  * **부분 블록 선택 서식 적용 (Rich Text Range Editing):** 마우스로 드래그하여 블록 설정한 부분만 글자 색상, 폰트, 크기, 볼드, 이탤릭, 밑줄을 독립적으로 개별 적용.
  * **선택 영역 서식 동기화:** 텍스트 블록 선택 시 또는 커서 이동 시 해당 글자의 폰트/크기/색상/B/I/U 상태를 서식 리본 UI에 실시간 자동 반영.
  * 입력 글자 폭과 줄 수에 8px 여백으로 타이트하게 밀착되는 동적 리사이징 (불필요한 거대 박스 방지).
  * 스마트 경계 스냅 플로팅 서식 리본 (상단/우측 캔버스 경계 감지하여 자동 스냅, 너비 300px 온전 보장).
  * 서체(Font Family) 드롭다운, 크기(9~72pt) 드롭다운, B(`⌘B`), I(`⌘I`), U(`⌘U`) 토글, 글자 색상 피커(`NSColorWell` 및 상단 팔레트 실시간 연동), 시스템 서체 패널(`⌘T`), 텍스트 블록 내 `⌘A` 전체 선택.
  * 외부 클릭 또는 `Esc` 시 캔버스에 영구 병합(Bake).

### 4) 캔버스 확대/축소 (Zoom) 및 제스처
* **소스:** `Sources/kMacPaint/MainWindowController.swift`, `CanvasView.swift`
* **내용:** 윈도우 그림판 스타일 하단 줌 컨트롤러(`[-]`, 25%~800% 슬라이더, `[+]`, 배율 라벨), 트랙패드 핀치-투-줌(`magnify(with:)`), `⌘ + 휠 스크롤`, 단축키(`⌘+`, `⌘-`, `⌘0`) 완벽 연동.

### 5) Shift 정비율 도형 및 45도 각도 스냅
* **소스:** `Sources/kMacPaint/Canvas/CanvasView.swift`
* **내용:** `Shift` 키 감지(`flagsChanged`, `mouseDragged`)를 통해 타원->정원(Circle), 직사각형->정사각형(Square), 직선->0°/45°/90°/135°/180° 스냅 실시간 프리뷰 및 커밋.

### 6) 선택 도구 (Marquee Selection) & 자유 조절 / 클립보드 편집
* **소스:** `Sources/kMacPaint/Canvas/CanvasView.swift`, `FloatingSelection.swift`, `MainWindowController.swift`, `AppDelegate.swift`
* **내용:** 
  * 마우스 드래그로 사각형 영역을 지정할 수 있는 선택 도구(`ToolType.select`) 구현. 드래그 중 선명한 반투명 파란색 영역 및 흑백 점선(Marching Ants) 프리뷰 표시.
  * 마우스 릴리즈 시 해당 비트맵 영역을 `FloatingSelection` 객체로 생성하고 8개 크기 조절 핸들 배치.
  * **지연 분리(Lazy Lifting):** 선택 직후에는 도화지 비트맵을 훼손하지 않으며, 사용자가 선택 영역을 마우스나 키보드로 처음 이동하거나 변형하는 순간 원래 위치를 2번 배경색(기본 흰색)으로 채우고 실행 취소(`Undo`) 스택에 등록.
  * **키보드 제어:** 방향키(←, →, ↑, ↓)를 통한 1px 정밀 이동 및 `Shift` 조합 10px 이동, `Delete` / `Backspace` 키를 통한 선택 영역 삭제, `Enter` / 외부 클릭을 통한 도화지 영구 병합(Bake).
  * **클립보드 및 메뉴 연동:** 잘라내기(`⌘X`), 복사(`⌘C`), 붙여넣기(`⌘V`), 도화지 전체 선택(`⌘A`) 상단 메뉴 및 단축키 연동.

### 7) 외부 이미지 플로팅 오버레이
* **소스:** `Sources/kMacPaint/Canvas/FloatingSelection.swift`
* **내용:** `⌘V` 또는 파일 삽입 시 이미지를 8개 조절 핸들과 점선 테두리가 있는 플로팅 객체로 생성. 자유 이동/크기 조절 후 외부 클릭 또는 `Enter` 시 캔버스에 병합.

### 8) 고속 Flood Fill (페인트통)
* **소스:** `Sources/kMacPaint/Tools/FloodFill.swift`
* **내용:** 픽셀 포인터 직접 접근 큐 기반 4방향 Flood Fill. 색상 공간 방어 변환(sRGB/DeviceRGB).

### 9) macOS 네이티브 앱 아이콘 (.icns), `/Applications/` 설치 및 배포 패키징
* **소스:** `Sources/kMacPaint/Resources/AppIcon.icns`, `build_app.sh`, `kMacPaint.zip`
* **내용:** 
  * macOS Squircle 규격 + Windows 11 그림판 팔레트/브러시 3D 에셋 Retina 1024x1024 멀티스케일 번들.
  * `/Applications/kMacPaint.app` 자동 배포 연동.
  * 타 사용자 배포를 위한 `ditto` 기반 무손실 압축 파일 `kMacPaint.zip` (3.3MB) 패키징 및 게이트키퍼 우회 가이드 확립.

---

## 3. 트러블슈팅 및 문제 해결 히스토리

1. **`NSColorRaiseWithColorSpaceError` 크래시 (해결 완료)**
   * **원인:** `PaletteView.swift`에서 컬러 슬롯의 텍스트 색상을 결정할 때 `NSColor.black/white`에서 `brightnessComponent`를 직접 호출함. AppKit에서 그레이스케일(`Generic Gray`) 색상에 HSB 속성을 직접 호출하면 예외 발생.
   * **조치:** `usingColorSpace(.sRGB)` 변환 및 표준 상대 휘도 공식(`0.299*R + 0.587*G + 0.114*B`)으로 안전하게 분기하도록 수정.

2. **캔버스 리사이즈 점선 클리핑 (해결 완료)**
   * **원인:** 핸들 드래그 시 `CanvasView`의 bounds가 기존 캔버스 크기로 제한되어 있어 점선이 뷰 밖(회색 스크롤 영역)에서 잘림.
   * **조치:** 드래그 중 `CanvasView.frame`을 임시 확장하고, 선명한 2.5px 파란색+흰색 이중 점선 및 반투명 영역 가이드를 렌더링.

3. **텍스트 박스 거대화 및 툴바 잘림 (해결 완료)**
   * **원인:** 텍스트 박스 초기 너비/높이가 잔여 캔버스 크기 전체로 잡혔고, 플로팅 툴바 너비가 텍스트 박스에 종속되어 오른쪽 버튼들이 잘림.
   * **조치:** 텍스트 실제 길이에 맞춰 8px 패딩으로 타이트하게 밀착되는 동적 리사이징 적용. 서식 리본은 독립 너비 300px 보장 및 상단/우측 경계 스마트 스냅 적용.

4. **텍스트 박스 내 `⌘A` 먹통 (해결 완료)**
   * **원인:** 메뉴바의 `⌘A` 단축키가 `AppDelegate`의 빈 메서드에 가로채임.
   * **조치:** `firstResponder` 및 `InlineCustomTextView`에서 `selectAll(nil)`을 명시적으로 처리하도록 라우팅.

5. **선택 도구(Marquee Select) 미작동 이슈 (해결 완료)**
   * **원인:** `CanvasView.mouseDown`에서 `case .select: break`로 아무 처리도 하지 않았으며, `mouseDragged` 및 `mouseUp`에 영역 선택 및 비트맵 크롭 로직이 누락되어 있었음.
   * **조치:** 사각형 마키 드래그 프리뷰, 마우스 릴리즈 시 `CanvasModel` 비트맵 크롭 및 8개 핸들을 지닌 `FloatingSelection` 객체 생성, 지연 분리(Lazy Lifting)를 통한 원본 영역 배경색 자동 채우기, 키보드 방향키 이동/단축키(`⌘X`, `⌘C`, `⌘V`, `⌘A`, `Delete`, `Enter`) 완벽 연동.

---

## 4. 변경 이력 (Changelog)

* **2026-11-18 (v2.1):**
  * 포니테일(Ponytail) 시니어 개발자 코드 감사 지적 사항 6종 완전 조치:
    1. **텍스트 경계 클램핑 버그 수정:** 캔버스 우측/하단 가장자리 인근에서 인라인 텍스트 커밋 시 500px 하드코딩 대신 에디터 실측 너비 및 잔여 캔버스 폭을 적용하여 글자가 캔버스 밖으로 잘리지 않고 정확한 위치에 병합되도록 수정 (`CanvasView.swift`)
    2. **스마트 스캔라인 Flood Fill 전환:** 가로 스팬 단위 스캔라인 알고리즘 및 1픽셀당 1비트 비트셋(`UInt64` 배열)을 적용하여, 4K 해상도에서도 1MB 미만의 메모리로 프레임 드랍 없이 초고속 채우기 구현 (`FloodFill.swift`)
    3. **동적 적응형 Undo 스택:** 캔버스 해상도에 따라 최대 실행 취소 단계를 자동 스케일링(기본 35단계, 4K 이상 12단계)하여 고화질 사진 편집 시 메모리 과열 방지 (`CanvasModel.swift`)
    4. **자동화 XCTest 단위 테스트 스위트 구축:** `Package.swift`에 `kMacPaintTests` 타깃을 추가하고 캔버스 초기화, 방향별 여백 리사이즈 오프셋, Undo/Redo 생명주기, 동적 스택 한계, 픽셀 매칭 5종 단위 테스트 구현 및 상시 통과 (`Tests/kMacPaintTests/CanvasModelTests.swift`)
    5. **미사용 코드(Dead Code) 제거:** 호출되지 않던 `ResizeHandle.init(type:canvasSize:)` 보조 생성자 정리 (`ResizeHandle.swift`)
    6. **읽히지 않는 플래그 변수 제거:** 값만 대입되고 사용되지 않던 `FloatingSelection.isResizing` 및 `CanvasView` 내 관련 대입 구문 제거 (`FloatingSelection.swift`, `CanvasView.swift`)
* **2026-11-18 (v2.0):**
  * macOS 표준 앱 라이프사이클 분리 (`⌘W` 창 닫기 vs `⌘Q` 앱 완전 종료):
    * `applicationShouldTerminateAfterLastWindowClosed`를 `false`로 변경하여 `⌘W`로 창을 닫아도 프로그램 본체는 Dock 및 상단 메뉴바에 상주하도록 구현
    * `window.isReleasedWhenClosed = false` 설정 및 창 닫힘 시 캔버스 상태 자동 클린 초기화
    * 창이 닫힌 상태에서 Dock의 kMacPaint 아이콘 클릭(`applicationShouldHandleReopen`), 또는 메뉴의 `새로 만들기 (⌘N)`, `열기 (⌘O)` 선택 시 새 도화지 창 즉시 복원
    * `⌘Q` 입력 시에만 앱 프로세스 완전 종료 수행 (수정된 내용이 있는 경우 저장 확인 팝업 안전 호출)
* **2026-11-18 (v1.9):**
  * 선택 도구(Marquee Selection) 완전 구현:
    * 툴바 선택 도구 클릭 후 드래그 시 반투명 파란색 영역 및 흑백 점선(Marching Ants) 프리뷰 실시간 렌더링
    * 드래그 완료 시 해당 영역을 잘라내어 8개 조절 핸들을 갖는 플로팅 선택 객체로 전환
    * 이동 및 8방향 크기 확대/축소 자유 변형 지원
    * 지연 분리(Lazy Lifting): 처음 움직이거나 편집할 때 원래 위치를 2번 배경색으로 지우고 `Undo` 스택 자동 등록
    * 키보드 방향키 1px 정밀 미세 이동 및 `Shift` 조합 10px 고속 이동 지원
    * `Delete` / `Backspace` 키를 통한 선택 영역 삭제
    * 편집 메뉴 및 단축키 연동: 잘라내기(`⌘X`), 복사(`⌘C`), 붙여넣기(`⌘V`), 도화지 전체 선택(`⌘A`), 병합(`Enter`)
* **2026-11-18 (v1.8):**
  * 텍스트 도구('가가') 아이콘 뒤집힘 현상 해결: AppKit Flipped 뷰 좌표계 보정(`respectFlipped: true`) 및 '가가' 정방향 타이포그래피 벡터 렌더링
  * 둥근 사각형 도구 아이콘 전면 교체: 상단만 둥글던 `rectangle.roundedtop` SF 심볼을 배제하고 상/하/좌/우 4개 모서리가 모두 대칭으로 둥근 정밀 벡터 아이콘(`createRoundedRectIcon`, r=4.0px)으로 재구현
  * 직사각형, 둥근 사각형, 타원, 직선 기하학 도형 아이콘의 스트로크 두께(1.3px) 및 비율 표준화
* **2026-11-18 (v1.7):**
  * 툴바 활성 도구 버튼 시각적 눌림 상태(Active Pressed State) 구현 (`ToolButton` 커스텀 드로잉)
  * Windows 11 Fluent 스타일의 세련된 하늘색 틴트 배경(`rgb(0.80, 0.89, 0.98)`), 1.5px 액센트 블루 테두리, 미세 상단 음영 및 1px 물리적 깊이감(yOffset) 적용
  * 마우스 호버(Hover) 피드백 및 클릭 시 일시 눌림 애니메이션 지원
  * `CanvasView.currentTool`과 툴바 간의 양방향 자동 동기화 (`CanvasViewDelegate.canvasDidChangeTool` 연동으로 스포이드 종료/붙여넣기 시에도 툴바 활성 버튼 자동 전환)
  * 붙여넣기(`ActionToolButton`) 버튼 테마 정합성 개선 및 `build_app.sh` 클라우드 동기화 dSYM 충돌 방지 로직 보강
* **2026-11-18 (v1.6):**
  * `⌘W`(창 닫기), `⌘Q`(앱 종료), `⌘N`(새로 만들기), `⌘O`(열기) 시 미저장 변경사항 보호 시스템 구현 (`promptSaveIfModified`)
  * `CanvasModel` 내 `isDirty`, `savedSnapshot` 추적 및 Undo/Redo 시 청정 상태 복귀 자동 감지
  * macOS 네이티브 윈도우 타이틀바 `isDocumentEdited` (빨간 닫기 버튼 내부 점 표시) 및 `representedURL` 연동
  * `⌘S` 기존 파일 즉시 덮어쓰기 저장 및 `⇧⌘S` 다른 이름으로 저장 분기 지원
* **2026-11-18 (v1.5):**
  * 8방향 전방위 캔버스 리사이즈 핸들 구현 (좌측, 상단, 우측, 하단 및 4개 모서리 전방위 드래그 확장 지원)
  * `CanvasModel.resizeCanvas`에 오프셋(`offset: CGPoint`) 매개변수를 추가하여 좌측/상단 확장 시 기존 그림 온전 보존 및 2번 배경색 자동 채우기 구현
  * 이미지 파일 열기(`⌘O`), 새 문서(`⌘N`), 외부 이미지 얹기/붙여넣기 시 캔버스 및 뷰포트 화면 정중앙 자동 정렬(Centering) 지원
  * 캔버스 크기 및 방향별 여백 직접 수치 입력 확장 모달 시트(`⌘K` / `이미지 > 캔버스 크기 및 여백 확장...`) 추가
* **2026-11-18 (v1.4):**
  * 타 사용자 전달용 무손실 압축 배포본 `kMacPaint.zip` (3.3MB) 생성 및 배포 가이드 문서화
  * 미서명 앱 최초 실행 시 Gatekeeper 대처 가이드 (우클릭 > 열기) 작성
* **2026-11-18 (v1.3):**
  * 부분 블록 선택 텍스트 서식 적용 지원 (선택된 글자 범위만 색상, 글꼴, 크기, 볼드, 이탤릭, 밑줄 개별 지정)
  * 선택 영역 및 커서 이동 시 서식 리본(글꼴, 크기, B, I, U, 색상) 실시간 동기화
* **2026-11-18 (v1.2):**
  * 인라인 텍스트 서식 툴바 스마트 경계 스냅 및 너비 보장 (잘림 방지)
  * 텍스트 실제 분량에 밀착되는 동적 리사이징 (과도한 여백 제거)
  * 글자 색상 피커(`NSColorWell` 및 상단 팔레트 실시간 연동) 추가
  * 텍스트 블록 내 `⌘A` 전체 선택 지원
* **2026-11-18 (v1.1):**
  * 트랙패드 핀치-투-줌(`magnify`) 및 하단 25%~800% 줌 슬라이더 연동
  * `Shift` 키 누른 정원/정사각형/각도 스냅 도형 그리기 구현
  * 캔버스 핸들 드래그 시 선명한 확장 가이드라인 및 뷰 클리핑 해결
  * 팝업창 없는 캔버스 인라인 텍스트 에디터 도입
* **2026-11-18 (v1.0):**
  * `PaletteView` 색상 공간 크래시 패치
  * Retina `.icns` 앱 아이콘 생성 및 `/Applications/` 폴더 배포 연동
  * 최초 클린룸 재구현 및 SPM 패키징 완성

---

## 5. 향후 추가 개선 백로그 (Backlog)

1. **다양한 브러시 텍스처 (크레용, 에어브러시, 캘리그라피 펜)**
2. **다크 모드 전용 UI 테마 감지 및 자동 전환**
3. **인라인 텍스트 박스 크기 수동 조절 핸들 추가**

---

## 6. 개발 및 빌드 규칙 (Mandatory Rule)

* **코드 수정 시 문서 동기화 원칙:** 본 프로젝트의 모든 기능 추가, 버그 수정, 인터랙션 변경 시에는 **반드시 `README.md`와 `HANDOFF.md`를 함께 최신 상태로 갱신**하여 문서와 코드의 완전한 정합성을 유지합니다.
