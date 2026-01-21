# testabc

3##adfadfa

3###adaf
*.msecnd.net:443
*.msecnd.net:443
*.msecnd.net:443
*.msecnd.net:443

1112313


3242342


123132



adfasdfasdfa1111

asdfasdf1111
11111
2342432aaaa111
11111111111111111111111

## 禁止 push 到 GitHub（本机策略）

安装（设置全局 pre-push hook，拦截远程地址包含 `github.com` 的 push）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_block_github_push.ps1 -Force
```

卸载：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall_block_github_push.ps1
```