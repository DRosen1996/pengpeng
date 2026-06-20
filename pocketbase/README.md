# PocketBase 部署（Apple 原生登录）

iOS 客户端调用 `POST /api/auth/apple`，由 `pb_hooks` 验 token、建用户并返回标准 `{ token, record }`。

## 目录

```
pocketbase/
├── .env.example
├── README.md
└── pb_hooks/
    ├── apple_jwt.js       # JWT 校验逻辑
    └── apple_auth.pb.js   # 路由 /api/auth/apple
```

## 部署到服务器

假设 PocketBase 二进制在 `/opt/pocketbase/`：

```bash
# 1. 上传 pb_hooks
scp -r pocketbase/pb_hooks user@1.14.226.184:/opt/pocketbase/

# 2. 配置环境变量（systemd 示例）
# Environment=APPLE_BUNDLE_ID=com.rosen.pengpeng

# 3. 重启 PocketBase
systemctl restart pocketbase
```

`pb_hooks` 必须与 `pocketbase` 可执行文件**同级**。修改 hook 文件后 Unix 下会自动热重载。

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `APPLE_BUNDLE_ID` | 推荐 | 默认 `com.rosen.pengpeng`，须与 iOS Bundle ID 一致 |
| `APPLE_JWT_CHECK_JWKS` | 否 | 设为 `true` 时额外校验 Apple JWKS 中是否存在 token 的 `kid` |

## 验证

```bash
# 路由应存在（无效 token 返回 400，不是 404）
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://1.14.226.184/api/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"identityToken":"invalid"}'
# 期望: 400
```

真机 Apple 登录成功后，响应格式与密码登录相同：

```json
{
  "token": "eyJ...",
  "record": { "id": "...", "email": "...", "name": "..." }
}
```

## 安全说明

当前实现使用 `$security.parseUnverifiedJWT` 校验 `exp/iat/nbf` 及 `iss`/`aud`/`sub`，**不包含 RS256 签名校验**。对原生客户端直连场景，建议在正式上线前增加 JWKS 验签（或确保仅 HTTPS + 真机环境）。

设置 `APPLE_JWT_CHECK_JWKS=true` 可额外确认 token 的 `kid` 在 Apple 公钥列表中，仍不能替代完整验签。

## 与 schema 的关系

- 不需要在 Admin 开启 Apple OAuth
- 用户绑定写入系统表 `_externalAuths`（`provider=apple`, `providerId=sub`）
- 新用户自动创建 `users` 记录；无邮箱时使用占位 `apple_xxx@apple.local`
