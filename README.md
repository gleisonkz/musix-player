# Musix Player

Player de multitracks para tocar ao vivo no iPad (projeto pessoal, sem App Store).

- Stems tocados em sincronia exata (AVAudioEngine, lidos direto do disco)
- **Modo Split** para cabo P2 → 2×P10: click + guia no **L**, banda (mono) no **R**
- Mixer por faixa: volume, mute, solo (solo nunca corta o click), troca de lado L/R
- Marcadores de seção (pular para verso/refrão), áudio em segundo plano, tela não apaga
- Aviso de vencimento da assinatura de 7 dias (Apple ID grátis)

## Instalar no iPad (Windows, Apple ID grátis)

1. Baixe o `.ipa` mais recente: <https://github.com/gleisonkz/musix-player/releases/download/latest/MusixPlayer.ipa>
2. Instale o [iTunes](https://www.apple.com/itunes/) (versão do site da Apple, não da Microsoft Store) e o [Sideloadly](https://sideloadly.io).
3. Conecte o iPad no cabo, abra o Sideloadly, arraste o `.ipa`, informe seu Apple ID e clique **Start**.
4. No iPad: **Ajustes → Geral → VPN e Gerenciamento de Dispositivo** → confie no seu Apple ID.
5. Na primeira vez, ative **Ajustes → Privacidade e Segurança → Modo de Desenvolvedor** (o iPad reinicia).

> A assinatura grátis vale **7 dias**. Repita o passo 3 antes de vencer (o app mostra quantos dias faltam).
> As músicas importadas **não são apagadas** ao reinstalar.

## Formato das músicas

Cada música é uma **pasta** com os stems (`.wav`, `.m4a`, `.mp3`, `.aif`, `.caf`, `.flac`).

Sem configuração nenhuma, o app reconhece pelo nome do arquivo:
- `Click`, `Clique`, `Metronomo` → **click** (lado L)
- `Guia`, `Guide`, `Cue` → **guia** (lado L)
- o resto → **banda** (lado R)

Opcionalmente, um `song.json` na pasta define título, BPM, tom e marcadores — veja
[`demo/DemoMusix/song.json`](demo/DemoMusix/song.json).

Para importar: botão **+** no app (iCloud Drive, Google Drive, pendrive…) ou copie a pasta para
**Arquivos → No Meu iPad → Musix**.

## Desenvolvimento

| Parte | Onde | Testes |
|---|---|---|
| `Core/Sources/MusixCore` | lógica pura (manifesto, roteamento, mixer, marcadores, assinatura) | `swift test --package-path Core` (roda no Windows) |
| `Core/Sources/MusixAudio` | motor AVAudioEngine | renderização offline, só macOS (CI) |
| `App/MusixPlayer` | app SwiftUI | build no CI |

O projeto Xcode é gerado por [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`).
O CI (GitHub Actions, macOS) roda os testes, compila o `.ipa` sem assinatura e publica no release `latest`.

Música demo sintética: `powershell -File tools/make_tts.ps1` e `python tools/make_demo_song.py`.
