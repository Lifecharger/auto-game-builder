"""Scaffolding for new Phaser 3 + TypeScript + Vite + Capacitor projects.

Writes all the template files so the project is immediately buildable with:
    npm install && npm run build
and wrappable for Android with:
    npx cap add android && npx cap sync android && cd android && gradlew.bat bundleRelease
"""

from __future__ import annotations

import os
import json
from typing import Optional


def scaffold_phaser_project(
    project_path: str,
    slug: str,
    app_name: str,
    package_name: str,
    keystore_path: Optional[str] = None,
    key_alias: Optional[str] = None,
    key_password: Optional[str] = None,
) -> None:
    """Create a complete Phaser + Capacitor project at project_path.

    Idempotent: never overwrites existing files. Safe to re-run.
    """
    os.makedirs(project_path, exist_ok=True)
    os.makedirs(os.path.join(project_path, "src"), exist_ok=True)
    os.makedirs(os.path.join(project_path, "src", "scenes"), exist_ok=True)
    os.makedirs(os.path.join(project_path, "src", "game"), exist_ok=True)
    os.makedirs(os.path.join(project_path, "public"), exist_ok=True)

    _write_if_missing(os.path.join(project_path, "package.json"),
                      _template_package_json(slug, app_name))
    _write_if_missing(os.path.join(project_path, "tsconfig.json"),
                      _template_tsconfig())
    _write_if_missing(os.path.join(project_path, "vite.config.ts"),
                      _template_vite_config())
    _write_if_missing(os.path.join(project_path, "capacitor.config.ts"),
                      _template_capacitor_config(
                          app_name, package_name,
                          keystore_path, key_alias, key_password,
                      ))
    _write_if_missing(os.path.join(project_path, "index.html"),
                      _template_index_html(app_name))
    _write_if_missing(os.path.join(project_path, ".gitignore"),
                      _template_gitignore())

    _write_if_missing(os.path.join(project_path, "src", "main.ts"),
                      _template_main_ts())
    _write_if_missing(os.path.join(project_path, "src", "scenes", "MenuScene.ts"),
                      _template_menu_scene(app_name))
    _write_if_missing(os.path.join(project_path, "src", "scenes", "GameScene.ts"),
                      _template_game_scene())


def _write_if_missing(path: str, content: str) -> None:
    if os.path.isfile(path):
        return
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)


def _template_package_json(slug: str, app_name: str) -> str:
    data = {
        "name": slug or "phaser-game",
        "version": "0.0.1",
        "private": True,
        "type": "module",
        "description": app_name,
        "scripts": {
            "dev": "vite",
            "build": "tsc --noEmit && vite build",
            "preview": "vite preview",
            "cap:add-android": "npx cap add android",
            "cap:sync": "npm run build && npx cap sync android",
            "cap:open": "npx cap open android",
            "android:aab": "npm run cap:sync && cd android && gradlew.bat bundleRelease",
            "android:apk": "npm run cap:sync && cd android && gradlew.bat assembleRelease",
        },
        "dependencies": {
            "phaser": "^3.80.1",
            "@capacitor/android": "^6.1.2",
            "@capacitor/core": "^6.1.2",
        },
        "devDependencies": {
            "@capacitor/cli": "^6.1.2",
            "typescript": "^5.4.5",
            "vite": "^5.2.11",
        },
    }
    return json.dumps(data, indent=2) + "\n"


def _template_tsconfig() -> str:
    return """{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "isolatedModules": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*.ts"]
}
"""


def _template_vite_config() -> str:
    return """import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  server: { host: true, port: 5173 },
  build: { target: 'es2020', outDir: 'dist' },
});
"""


def _template_capacitor_config(
    app_name: str,
    package_name: str,
    keystore_path: Optional[str],
    key_alias: Optional[str],
    key_password: Optional[str],
) -> str:
    # Signing config is only written if keystore info was provided.
    # Kept out of the public repo by .gitignore — this file contains passwords.
    signing_block = ""
    if keystore_path and key_alias and key_password:
        # Escape backslashes for TypeScript string literal
        ks_path_ts = keystore_path.replace("\\", "\\\\")
        signing_block = f"""
      buildOptions: {{
        keystorePath: '{ks_path_ts}',
        keystoreAlias: '{key_alias}',
        keystorePassword: '{key_password}',
        keystoreAliasPassword: '{key_password}',
        releaseType: 'AAB',
        signingType: 'apksigner',
      }},"""

    return f"""import type {{ CapacitorConfig }} from '@capacitor/cli';

// WARNING: contains signing passwords — see .gitignore
const config: CapacitorConfig = {{
  appId: '{package_name or "com.example.game"}',
  appName: '{app_name.replace("'", "\\'")}',
  webDir: 'dist',
  android: {{{signing_block}
  }},
}};

export default config;
"""


def _template_index_html(app_name: str) -> str:
    safe_name = app_name.replace("<", "&lt;").replace(">", "&gt;")
    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover" />
    <title>{safe_name}</title>
    <style>
      html, body {{ margin: 0; padding: 0; height: 100%; background: #101018; overflow: hidden; touch-action: none; }}
      body {{ display: flex; align-items: center; justify-content: center; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }}
      #game {{ width: 100vw; height: 100vh; }}
    </style>
  </head>
  <body>
    <div id="game"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
"""


def _template_gitignore() -> str:
    return """node_modules/
dist/
.vite/
*.log
.DS_Store

# Capacitor generates these; keep out of version control
android/
ios/

# Contains signing passwords
capacitor.config.ts
"""


def _template_main_ts() -> str:
    return """import Phaser from 'phaser';
import { MenuScene } from './scenes/MenuScene';
import { GameScene } from './scenes/GameScene';

export const GAME_WIDTH = 400;
export const GAME_HEIGHT = 700;

new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  backgroundColor: '#101018',
  width: GAME_WIDTH,
  height: GAME_HEIGHT,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  render: {
    antialias: true,
    pixelArt: false,
  },
  scene: [MenuScene, GameScene],
});
"""


def _template_menu_scene(app_name: str) -> str:
    safe = app_name.replace("'", "\\'")
    return f"""import Phaser from 'phaser';
import {{ GAME_WIDTH, GAME_HEIGHT }} from '../main';

export class MenuScene extends Phaser.Scene {{
  constructor() {{ super('MenuScene'); }}

  create() {{
    this.add.text(GAME_WIDTH / 2, GAME_HEIGHT / 2 - 60, '{safe}', {{
      fontFamily: 'sans-serif',
      fontSize: '32px',
      color: '#ffffff',
      fontStyle: 'bold',
    }}).setOrigin(0.5);

    const playBtn = this.add.rectangle(
      GAME_WIDTH / 2, GAME_HEIGHT / 2 + 20, 200, 60, 0x3050a0, 1,
    ).setStrokeStyle(2, 0x80a0e0).setInteractive({{ useHandCursor: true }});

    this.add.text(GAME_WIDTH / 2, GAME_HEIGHT / 2 + 20, 'PLAY', {{
      fontFamily: 'sans-serif',
      fontSize: '22px',
      color: '#ffffff',
      fontStyle: 'bold',
    }}).setOrigin(0.5);

    playBtn.on('pointerover', () => playBtn.setFillStyle(0x4060c0));
    playBtn.on('pointerout', () => playBtn.setFillStyle(0x3050a0));
    playBtn.on('pointerdown', () => this.scene.start('GameScene'));
  }}
}}
"""


def _template_game_scene() -> str:
    return """import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT } from '../main';

export class GameScene extends Phaser.Scene {
  constructor() { super('GameScene'); }

  create() {
    this.add.text(GAME_WIDTH / 2, 30, 'GameScene', {
      fontFamily: 'sans-serif', fontSize: '18px', color: '#9a9aaa',
    }).setOrigin(0.5, 0);

    this.add.text(GAME_WIDTH / 2, GAME_HEIGHT / 2, 'Your game goes here', {
      fontFamily: 'sans-serif', fontSize: '16px', color: '#ffffff',
    }).setOrigin(0.5);

    // Back-to-menu button
    const backBtn = this.add.text(10, 10, '← menu', {
      fontFamily: 'sans-serif', fontSize: '14px', color: '#9a9aaa',
    }).setInteractive({ useHandCursor: true });
    backBtn.on('pointerdown', () => this.scene.start('MenuScene'));

    // CRITICAL: scene-scoped cleanup. Phaser tears down display objects when
    // this scene stops, but any external refs (timers, pools, plugins) must
    // be released here to prevent leaks across scene transitions.
    this.events.once('shutdown', this.cleanup, this);
    this.events.once('destroy', this.cleanup, this);
  }

  private cleanup() {
    // Release external resources here (object pools, websockets, audio, etc.)
  }
}
"""
