# testabc
23342342342

23423424
2342342

2222


ddd


## 禁止 push 到 GitHub（本机策略）

安装（设置全局 pre-push hook，拦截远程地址包含 `github.com` 的 push）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_block_github_push.ps1 -Force
```

卸载：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall_block_github_push.ps1
```