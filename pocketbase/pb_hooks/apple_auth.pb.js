/// <reference path="../pb_data/types.d.ts" />

routerAdd("POST", "/api/auth/apple", function (e) {
    var appleJwt = require(__hooks + "/apple_jwt.js");

    var body = new DynamicModel({
        identityToken: "",
        fullName: "",
    });
    e.bindBody(body);

    if (!body.identityToken) {
        throw new BadRequestError("缺少 identityToken");
    }

    var bundleId = $os.getenv("APPLE_BUNDLE_ID") || "com.rosen.pengpeng";
    var fullName = body.fullName ? String(body.fullName).trim() : "";
    if (fullName === "") {
        fullName = "";
    }

    var claims;
    try {
        claims = appleJwt.verifyIdentityToken(body.identityToken, bundleId);
    } catch (err) {
        throw new BadRequestError("Apple 登录凭证无效");
    }

    var usersCollection = $app.findCollectionByNameOrId("users");
    var collectionRef = usersCollection.id;
    var provider = "apple";
    var providerId = claims.sub;

    var record = findAppleUser(collectionRef, provider, providerId);

    if (!record) {
        try {
            record = createAppleUser(usersCollection, collectionRef, claims, fullName);
        } catch (err) {
            // 并发首次登录时可能撞唯一索引，回查一次
            record = findAppleUser(collectionRef, provider, providerId);
            if (!record) {
                throw new BadRequestError("创建用户失败，请重试");
            }
        }
    } else if (fullName && !record.get("name")) {
        record.set("name", fullName);
        $app.save(record);
    }

    return $apis.recordAuthResponse(e, record, "apple");
});

function findAppleUser(collectionRef, provider, providerId) {
    try {
        var extAuth = $app.findFirstExternalAuthByExpr(
            $dbx.hashExp({
                collectionRef: collectionRef,
                provider: provider,
                providerId: providerId,
            })
        );
        return $app.findRecordById("users", extAuth.recordRef());
    } catch (err) {
        return null;
    }
}

function createAppleUser(usersCollection, collectionRef, claims, fullName) {
    var record = new Record(usersCollection);

    var email = claims.email;
    if (!email) {
        email = "apple_" + claims.sub.substring(0, 12) + "@apple.local";
    }

    record.set("email", email);
    record.setRandomPassword();
    record.setVerified(true);

    if (fullName) {
        record.set("name", fullName);
    }

    $app.save(record);

    var extAuth = newExternalAuth($app);
    extAuth.setCollectionRef(collectionRef);
    extAuth.setRecordRef(record.id);
    extAuth.setProvider("apple");
    extAuth.setProviderId(claims.sub);
    $app.save(extAuth);

    return record;
}
