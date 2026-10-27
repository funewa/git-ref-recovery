# git-ref-recovery

> WorkBuddy Skill — `git-ref-recovery`

## 简介

Diagnose and recover a Git repository whose remote refs were force-reset, rewound, or diverged by a parallel/competing process, or whose porcelain commands are silently swallowed by a sandbox. Use when local branches disagree with origin, when commit

## 安装

```bash
git clone https://github.com/funewa/git-ref-recovery.git
cp -r git-ref-recovery ~/.workbuddy/skills/git-ref-recovery
```

## 使用

在 WorkBuddy 中直接描述你的需求，Agent 会依据 `SKILL.md` 的 `description` 自动匹配本技能。详见 `SKILL.md`。

## 目录结构

```
├── SKILL.md      # 技能定义（frontmatter + 说明）
├── scripts/
└── README.md
```

---

Published from the `user`-level WorkBuddy skill library.
