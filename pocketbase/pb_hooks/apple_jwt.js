/**
 * Apple identityToken 校验（供 apple_auth.pb.js require）
 *
 * 使用 $security.parseUnverifiedJWT 校验 exp/iat/nbf，并检查 iss/aud/sub。
 * 注：完整 RS256 签名校验需 JWKS，见 pocketbase/README.md。
 */
module.exports = {
    APPLE_ISSUER: "https://appleid.apple.com",
    APPLE_JWKS_URL: "https://appleid.apple.com/auth/keys",

    verifyIdentityToken: function (identityToken, bundleId) {
        if (!identityToken || typeof identityToken !== "string") {
            throw new Error("missing identityToken");
        }

        var token = identityToken.trim();
        if (token.split(".").length !== 3) {
            throw new Error("invalid token format");
        }

        var claims = $security.parseUnverifiedJWT(token);

        if (claims.iss !== this.APPLE_ISSUER) {
            throw new Error("invalid iss");
        }

        if (!this._audienceMatches(claims.aud, bundleId)) {
            throw new Error("invalid aud");
        }

        if (!claims.sub) {
            throw new Error("missing sub");
        }

        // 可选：拉取 JWKS 确认 kid 存在（不验签，仅防明显伪造）
        if ($os.getenv("APPLE_JWT_CHECK_JWKS") === "true") {
            this._assertKnownSigningKey(token);
        }

        return {
            sub: String(claims.sub),
            email: claims.email ? String(claims.email) : "",
        };
    },

    _audienceMatches: function (aud, bundleId) {
        if (!bundleId) {
            return false;
        }
        if (typeof aud === "string") {
            return aud === bundleId;
        }
        if (aud && typeof aud.length === "number") {
            for (var i = 0; i < aud.length; i++) {
                if (aud[i] === bundleId) {
                    return true;
                }
            }
        }
        return false;
    },

    _assertKnownSigningKey: function (token) {
        var headerPart = token.split(".")[0];
        var headerJson = this._base64UrlDecode(headerPart);
        var header = JSON.parse(headerJson);
        if (!header.kid) {
            throw new Error("missing kid");
        }

        var response = $http.send({
            url: this.APPLE_JWKS_URL,
            method: "GET",
            timeout: 10,
        });
        if (response.statusCode !== 200) {
            throw new Error("failed to fetch Apple JWKS");
        }

        var jwks = response.json;
        if (!jwks || !jwks.keys || !jwks.keys.length) {
            throw new Error("empty Apple JWKS");
        }

        for (var i = 0; i < jwks.keys.length; i++) {
            if (jwks.keys[i].kid === header.kid) {
                return;
            }
        }
        throw new Error("unknown signing key");
    },

    _base64UrlDecode: function (input) {
        var str = String(input).replace(/-/g, "+").replace(/_/g, "/");
        var pad = str.length % 4;
        if (pad === 2) {
            str += "==";
        } else if (pad === 3) {
            str += "=";
        } else if (pad === 1) {
            throw new Error("invalid base64url");
        }
        return this._base64Decode(str);
    },

    _base64Decode: function (str) {
        var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
        var decoded = "";
        var i = 0;
        str = str.replace(/[^A-Za-z0-9+/=]/g, "");

        while (i < str.length) {
            var enc1 = chars.indexOf(str.charAt(i++));
            var enc2 = chars.indexOf(str.charAt(i++));
            var enc3 = chars.indexOf(str.charAt(i++));
            var enc4 = chars.indexOf(str.charAt(i++));

            var char1 = (enc1 << 2) | (enc2 >> 4);
            var char2 = ((enc2 & 15) << 4) | (enc3 >> 2);
            var char3 = ((enc3 & 3) << 6) | enc4;

            decoded += String.fromCharCode(char1);
            if (enc3 !== 64) {
                decoded += String.fromCharCode(char2);
            }
            if (enc4 !== 64) {
                decoded += String.fromCharCode(char3);
            }
        }
        return decoded;
    },
};
