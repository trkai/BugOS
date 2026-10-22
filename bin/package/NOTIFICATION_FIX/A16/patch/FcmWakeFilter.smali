.class public Lcom/android/server/am/FcmWakeFilter;
.super Ljava/lang/Object;
.source "FcmWakeFilter.java"


# static fields
.field private static final CONFIG_CHECK_INTERVAL_MS:J = 0x1388L

.field public static final CONF_PATH:Ljava/lang/String; = "/data/system/fcm_wake.conf"

.field public static final FLAG_INCLUDE_STOPPED_PACKAGES:I = 0x20

.field private static final GMS_PKG:Ljava/lang/String; = "com.google.android.gms"

.field public static final MODE_ALL:I = 0x0

.field public static final MODE_BLACKLIST:I = 0x2

.field public static final MODE_WHITELIST:I = 0x1

.field private static volatile sCurrentMode:I

.field private static volatile sLastCheckTimestamp:J

.field private static volatile sLastModified:J

.field private static volatile sPackageFilterSet:Ljava/util/Set;
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "Ljava/util/Set<",
            "Ljava/lang/String;",
            ">;"
        }
    .end annotation
.end field

.field private static final sPendingCallee:Ljava/lang/ThreadLocal;
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "Ljava/lang/ThreadLocal<",
            "Ljava/lang/String;",
            ">;"
        }
    .end annotation
.end field


# direct methods
.method static constructor <clinit>()V
    .registers 2

    .line 33
    new-instance v0, Ljava/lang/ThreadLocal;

    invoke-direct {v0}, Ljava/lang/ThreadLocal;-><init>()V

    sput-object v0, Lcom/android/server/am/FcmWakeFilter;->sPendingCallee:Ljava/lang/ThreadLocal;

    .line 35
    const-wide/16 v0, -0x1

    sput-wide v0, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J

    .line 36
    const/4 v0, 0x0

    sput v0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    .line 37
    invoke-static {}, Ljava/util/Collections;->emptySet()Ljava/util/Set;

    move-result-object v0

    sput-object v0, Lcom/android/server/am/FcmWakeFilter;->sPackageFilterSet:Ljava/util/Set;

    .line 38
    const-wide/16 v0, 0x0

    sput-wide v0, Lcom/android/server/am/FcmWakeFilter;->sLastCheckTimestamp:J

    return-void
.end method

.method public constructor <init>()V
    .registers 1

    .line 23
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static applyFlags(Landroid/content/Intent;)V
    .registers 6

    .line 91
    if-nez p0, :cond_3

    .line 92
    return-void

    .line 95
    :cond_3
    invoke-virtual {p0}, Landroid/content/Intent;->getAction()Ljava/lang/String;

    move-result-object v0

    .line 96
    if-eqz v0, :cond_4e

    const-string v1, "com.google.android.c2dm.intent.RECEIVE"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v0

    if-nez v0, :cond_12

    goto :goto_4e

    .line 101
    :cond_12
    invoke-static {}, Lcom/android/server/am/FcmWakeFilter;->checkConfig()V

    .line 103
    sget v0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    const/16 v1, 0x20

    if-nez v0, :cond_1f

    .line 104
    invoke-virtual {p0, v1}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;

    .line 105
    return-void

    .line 108
    :cond_1f
    invoke-static {p0}, Lcom/android/server/am/FcmWakeFilter;->getTargetPackage(Landroid/content/Intent;)Ljava/lang/String;

    move-result-object v0

    .line 110
    const/4 v2, 0x2

    if-eqz v0, :cond_46

    invoke-virtual {v0}, Ljava/lang/String;->isEmpty()Z

    move-result v3

    if-eqz v3, :cond_2d

    goto :goto_46

    .line 118
    :cond_2d
    invoke-static {v0}, Lcom/android/server/am/FcmWakeFilter;->isPackageInFilterSet(Ljava/lang/String;)Z

    move-result v0

    .line 120
    sget v3, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    const/4 v4, 0x1

    if-ne v3, v4, :cond_3c

    .line 122
    if-eqz v0, :cond_45

    .line 123
    invoke-virtual {p0, v1}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;

    goto :goto_45

    .line 125
    :cond_3c
    sget v3, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-ne v3, v2, :cond_45

    .line 127
    if-nez v0, :cond_45

    .line 128
    invoke-virtual {p0, v1}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;

    .line 131
    :cond_45
    :goto_45
    return-void

    .line 112
    :cond_46
    :goto_46
    sget v0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-ne v0, v2, :cond_4d

    .line 113
    invoke-virtual {p0, v1}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;

    .line 115
    :cond_4d
    return-void

    .line 97
    :cond_4e
    :goto_4e
    return-void
.end method

.method public static basePackage(Ljava/lang/String;)Ljava/lang/String;
    .registers 3

    .line 81
    if-nez p0, :cond_4

    const/4 p0, 0x0

    return-object p0

    .line 82
    :cond_4
    const/16 v0, 0x3a

    invoke-virtual {p0, v0}, Ljava/lang/String;->indexOf(I)I

    move-result v0

    .line 83
    if-lez v0, :cond_11

    const/4 v1, 0x0

    invoke-virtual {p0, v1, v0}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object p0

    :cond_11
    return-object p0
.end method

.method private static checkConfig()V
    .registers 6

    .line 227
    invoke-static {}, Landroid/os/SystemClock;->elapsedRealtime()J

    move-result-wide v0

    .line 228
    sget-wide v2, Lcom/android/server/am/FcmWakeFilter;->sLastCheckTimestamp:J

    sub-long v2, v0, v2

    const-wide/16 v4, 0x1388

    cmp-long v2, v2, v4

    if-gez v2, :cond_17

    sget-wide v2, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J

    const-wide/16 v4, 0x0

    cmp-long v2, v2, v4

    if-ltz v2, :cond_17

    .line 229
    return-void

    .line 231
    :cond_17
    sput-wide v0, Lcom/android/server/am/FcmWakeFilter;->sLastCheckTimestamp:J

    .line 232
    invoke-static {}, Lcom/android/server/am/FcmWakeFilter;->syncConfigInternal()V

    .line 233
    return-void
.end method

.method public static checkGreezeAllowRequest(Ljava/lang/String;)I
    .registers 3

    .line 57
    sget-object v0, Lcom/android/server/am/FcmWakeFilter;->sPendingCallee:Ljava/lang/ThreadLocal;

    invoke-virtual {v0}, Ljava/lang/ThreadLocal;->get()Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Ljava/lang/String;

    .line 58
    sget-object v1, Lcom/android/server/am/FcmWakeFilter;->sPendingCallee:Ljava/lang/ThreadLocal;

    invoke-virtual {v1}, Ljava/lang/ThreadLocal;->remove()V

    .line 60
    const-string v1, "com.google.android.gms"

    invoke-virtual {v1, p0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p0

    if-nez p0, :cond_17

    .line 61
    const/4 p0, -0x1

    return p0

    .line 63
    :cond_17
    invoke-static {}, Lcom/android/server/am/FcmWakeFilter;->checkConfig()V

    .line 64
    sget p0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    const/4 v1, 0x1

    if-nez p0, :cond_20

    .line 65
    return v1

    .line 67
    :cond_20
    if-eqz v0, :cond_38

    invoke-virtual {v0}, Ljava/lang/String;->isEmpty()Z

    move-result p0

    if-eqz p0, :cond_29

    goto :goto_38

    .line 70
    :cond_29
    invoke-static {v0}, Lcom/android/server/am/FcmWakeFilter;->basePackage(Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    invoke-static {p0}, Lcom/android/server/am/FcmWakeFilter;->isPackageInFilterSet(Ljava/lang/String;)Z

    move-result p0

    .line 71
    sget v0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-ne v0, v1, :cond_36

    .line 72
    return p0

    .line 74
    :cond_36
    xor-int/2addr p0, v1

    return p0

    .line 68
    :cond_38
    :goto_38
    sget p0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    const/4 v0, 0x2

    if-ne p0, v0, :cond_3e

    goto :goto_3f

    :cond_3e
    const/4 v1, 0x0

    :goto_3f
    return v1
.end method

.method public static checkGreezeBroadcastAllow(Ljava/lang/String;Ljava/lang/String;)I
    .registers 4

    .line 143
    if-eqz p0, :cond_3f

    const-string v0, "com.google.android.c2dm.intent.RECEIVE"

    invoke-virtual {p0, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p0

    if-nez p0, :cond_b

    goto :goto_3f

    .line 148
    :cond_b
    invoke-static {}, Lcom/android/server/am/FcmWakeFilter;->checkConfig()V

    .line 150
    sget p0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    const/4 v0, 0x1

    if-nez p0, :cond_14

    .line 151
    return v0

    .line 154
    :cond_14
    invoke-static {p1}, Lcom/android/server/am/FcmWakeFilter;->basePackage(Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    .line 155
    if-eqz p0, :cond_1e

    .line 156
    invoke-virtual {p0}, Ljava/lang/String;->trim()Ljava/lang/String;

    move-result-object p0

    .line 159
    :cond_1e
    const/4 p1, 0x2

    if-eqz p0, :cond_38

    invoke-virtual {p0}, Ljava/lang/String;->isEmpty()Z

    move-result v1

    if-eqz v1, :cond_28

    goto :goto_38

    .line 163
    :cond_28
    invoke-static {p0}, Lcom/android/server/am/FcmWakeFilter;->isPackageInFilterSet(Ljava/lang/String;)Z

    move-result p0

    .line 165
    sget v1, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-ne v1, v0, :cond_31

    .line 166
    return p0

    .line 167
    :cond_31
    sget v1, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-ne v1, p1, :cond_37

    .line 168
    xor-int/2addr p0, v0

    return p0

    .line 171
    :cond_37
    return v0

    .line 160
    :cond_38
    :goto_38
    sget p0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-ne p0, p1, :cond_3d

    goto :goto_3e

    :cond_3d
    const/4 v0, 0x0

    :goto_3e
    return v0

    .line 144
    :cond_3f
    :goto_3f
    const/4 p0, -0x1

    return p0
.end method

.method public static getTargetPackage(Landroid/content/Intent;)Ljava/lang/String;
    .registers 3

    .line 200
    if-nez p0, :cond_4

    const/4 p0, 0x0

    return-object p0

    .line 201
    :cond_4
    invoke-virtual {p0}, Landroid/content/Intent;->getPackage()Ljava/lang/String;

    move-result-object v0

    .line 202
    if-nez v0, :cond_14

    .line 203
    invoke-virtual {p0}, Landroid/content/Intent;->getComponent()Landroid/content/ComponentName;

    move-result-object v1

    .line 204
    if-eqz v1, :cond_14

    .line 205
    invoke-virtual {v1}, Landroid/content/ComponentName;->getPackageName()Ljava/lang/String;

    move-result-object v0

    .line 208
    :cond_14
    if-nez v0, :cond_3c

    invoke-virtual {p0}, Landroid/content/Intent;->getSelector()Landroid/content/Intent;

    move-result-object v1

    if-eqz v1, :cond_3c

    .line 209
    invoke-virtual {p0}, Landroid/content/Intent;->getSelector()Landroid/content/Intent;

    move-result-object v0

    invoke-virtual {v0}, Landroid/content/Intent;->getPackage()Ljava/lang/String;

    move-result-object v0

    .line 210
    if-nez v0, :cond_3c

    invoke-virtual {p0}, Landroid/content/Intent;->getSelector()Landroid/content/Intent;

    move-result-object v1

    invoke-virtual {v1}, Landroid/content/Intent;->getComponent()Landroid/content/ComponentName;

    move-result-object v1

    if-eqz v1, :cond_3c

    .line 211
    invoke-virtual {p0}, Landroid/content/Intent;->getSelector()Landroid/content/Intent;

    move-result-object p0

    invoke-virtual {p0}, Landroid/content/Intent;->getComponent()Landroid/content/ComponentName;

    move-result-object p0

    invoke-virtual {p0}, Landroid/content/ComponentName;->getPackageName()Ljava/lang/String;

    move-result-object v0

    .line 214
    :cond_3c
    if-eqz v0, :cond_42

    .line 215
    invoke-virtual {v0}, Ljava/lang/String;->trim()Ljava/lang/String;

    move-result-object v0

    .line 217
    :cond_42
    return-object v0
.end method

.method public static isAllowBroadcast()Z
    .registers 1

    .line 195
    invoke-static {}, Lcom/android/server/am/FcmWakeFilter;->checkConfig()V

    .line 196
    sget v0, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    if-nez v0, :cond_9

    const/4 v0, 0x1

    goto :goto_a

    :cond_9
    const/4 v0, 0x0

    :goto_a
    return v0
.end method

.method public static isAllowBroadcast(Landroid/content/Intent;)Z
    .registers 2

    .line 191
    const/4 v0, 0x0

    invoke-static {p0, v0}, Lcom/android/server/am/FcmWakeFilter;->isAllowBroadcast(Landroid/content/Intent;Ljava/lang/String;)Z

    move-result p0

    return p0
.end method

.method public static isAllowBroadcast(Landroid/content/Intent;Ljava/lang/String;)Z
    .registers 3

    .line 180
    if-nez p0, :cond_4

    .line 181
    const/4 p0, 0x0

    return p0

    .line 183
    :cond_4
    nop

    .line 184
    if-eqz p1, :cond_d

    invoke-virtual {p1}, Ljava/lang/String;->isEmpty()Z

    move-result v0

    if-eqz v0, :cond_11

    .line 185
    :cond_d
    invoke-static {p0}, Lcom/android/server/am/FcmWakeFilter;->getTargetPackage(Landroid/content/Intent;)Ljava/lang/String;

    move-result-object p1

    .line 187
    :cond_11
    invoke-virtual {p0}, Landroid/content/Intent;->getAction()Ljava/lang/String;

    move-result-object p0

    invoke-static {p0, p1}, Lcom/android/server/am/FcmWakeFilter;->isAllowBroadcast(Ljava/lang/String;Ljava/lang/String;)Z

    move-result p0

    return p0
.end method

.method public static isAllowBroadcast(Ljava/lang/String;Ljava/lang/String;)Z
    .registers 2

    .line 175
    invoke-static {p0, p1}, Lcom/android/server/am/FcmWakeFilter;->checkGreezeBroadcastAllow(Ljava/lang/String;Ljava/lang/String;)I

    move-result p0

    .line 176
    if-lez p0, :cond_8

    const/4 p0, 0x1

    goto :goto_9

    :cond_8
    const/4 p0, 0x0

    :goto_9
    return p0
.end method

.method public static isPackageInFilterSet(Ljava/lang/String;)Z
    .registers 4

    .line 221
    const/4 v0, 0x0

    if-nez p0, :cond_4

    return v0

    .line 222
    :cond_4
    sget-object v1, Lcom/android/server/am/FcmWakeFilter;->sPackageFilterSet:Ljava/util/Set;

    .line 223
    invoke-interface {v1, p0}, Ljava/util/Set;->contains(Ljava/lang/Object;)Z

    move-result v2

    if-nez v2, :cond_16

    invoke-virtual {p0}, Ljava/lang/String;->toLowerCase()Ljava/lang/String;

    move-result-object p0

    invoke-interface {v1, p0}, Ljava/util/Set;->contains(Ljava/lang/Object;)Z

    move-result p0

    if-eqz p0, :cond_17

    :cond_16
    const/4 v0, 0x1

    :cond_17
    return v0
.end method

.method public static noteGreezeCallee(Ljava/lang/String;)V
    .registers 2

    .line 46
    sget-object v0, Lcom/android/server/am/FcmWakeFilter;->sPendingCallee:Ljava/lang/ThreadLocal;

    invoke-virtual {v0, p0}, Ljava/lang/ThreadLocal;->set(Ljava/lang/Object;)V

    .line 47
    return-void
.end method

.method private static declared-synchronized syncConfigInternal()V
    .registers 10

    const-class v0, Lcom/android/server/am/FcmWakeFilter;

    monitor-enter v0

    .line 237
    const/4 v1, 0x0

    :try_start_4
    new-instance v2, Ljava/io/File;

    const-string v3, "/data/system/fcm_wake.conf"

    invoke-direct {v2, v3}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    .line 238
    invoke-virtual {v2}, Ljava/io/File;->exists()Z

    move-result v3

    const-wide/16 v4, 0x0

    if-nez v3, :cond_25

    .line 239
    sget-wide v2, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J

    cmp-long v2, v2, v4

    if-eqz v2, :cond_23

    .line 240
    sput v1, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    .line 241
    invoke-static {}, Ljava/util/Collections;->emptySet()Ljava/util/Set;

    move-result-object v2

    sput-object v2, Lcom/android/server/am/FcmWakeFilter;->sPackageFilterSet:Ljava/util/Set;

    .line 242
    sput-wide v4, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J
    :try_end_23
    .catchall {:try_start_4 .. :try_end_23} :catchall_c4

    .line 244
    :cond_23
    monitor-exit v0

    return-void

    .line 247
    :cond_25
    :try_start_25
    invoke-virtual {v2}, Ljava/io/File;->lastModified()J

    move-result-wide v6

    .line 248
    sget-wide v8, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J

    cmp-long v3, v6, v8

    if-nez v3, :cond_37

    sget-wide v8, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J
    :try_end_31
    .catchall {:try_start_25 .. :try_end_31} :catchall_c4

    cmp-long v3, v8, v4

    if-lez v3, :cond_37

    .line 249
    monitor-exit v0

    return-void

    .line 252
    :cond_37
    :try_start_37
    new-instance v3, Ljava/util/HashSet;

    invoke-direct {v3}, Ljava/util/HashSet;-><init>()V
    :try_end_3c
    .catchall {:try_start_37 .. :try_end_3c} :catchall_c4

    .line 253
    nop

    .line 255
    nop

    .line 257
    const/4 v4, 0x0

    :try_start_3f
    new-instance v5, Ljava/io/BufferedReader;

    new-instance v8, Ljava/io/FileReader;

    invoke-direct {v8, v2}, Ljava/io/FileReader;-><init>(Ljava/io/File;)V

    invoke-direct {v5, v8}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V
    :try_end_49
    .catchall {:try_start_3f .. :try_end_49} :catchall_bb

    move v2, v1

    .line 259
    :cond_4a
    :goto_4a
    :try_start_4a
    invoke-virtual {v5}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;

    move-result-object v4

    if-eqz v4, :cond_a6

    .line 260
    invoke-virtual {v4}, Ljava/lang/String;->trim()Ljava/lang/String;

    move-result-object v4

    .line 261
    invoke-virtual {v4}, Ljava/lang/String;->isEmpty()Z

    move-result v8

    if-nez v8, :cond_4a

    const-string v8, "#"

    invoke-virtual {v4, v8}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v8

    if-eqz v8, :cond_63

    .line 262
    goto :goto_4a

    .line 264
    :cond_63
    const-string v8, "MODE=WHITELIST"

    invoke-virtual {v4, v8}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v8

    if-nez v8, :cond_a4

    const-string v8, "MODE=SELECTED"

    invoke-virtual {v4, v8}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v8

    if-eqz v8, :cond_74

    goto :goto_a4

    .line 266
    :cond_74
    const-string v8, "MODE=BLACKLIST"

    invoke-virtual {v4, v8}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v8

    if-nez v8, :cond_a2

    const-string v8, "MODE=BLOCK"

    invoke-virtual {v4, v8}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v8

    if-eqz v8, :cond_85

    goto :goto_a2

    .line 268
    :cond_85
    const-string v8, "MODE=ALL"

    invoke-virtual {v4, v8}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v8

    if-eqz v8, :cond_8f

    .line 269
    move v2, v1

    goto :goto_4a

    .line 270
    :cond_8f
    const-string v8, "="

    invoke-virtual {v4, v8}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v8

    if-nez v8, :cond_4a

    .line 271
    invoke-interface {v3, v4}, Ljava/util/Set;->add(Ljava/lang/Object;)Z

    .line 272
    invoke-virtual {v4}, Ljava/lang/String;->toLowerCase()Ljava/lang/String;

    move-result-object v4

    invoke-interface {v3, v4}, Ljava/util/Set;->add(Ljava/lang/Object;)Z
    :try_end_a1
    .catchall {:try_start_4a .. :try_end_a1} :catchall_b8

    goto :goto_4a

    .line 267
    :cond_a2
    :goto_a2
    const/4 v2, 0x2

    goto :goto_4a

    .line 265
    :cond_a4
    :goto_a4
    const/4 v2, 0x1

    goto :goto_4a

    .line 276
    :cond_a6
    nop

    .line 278
    :try_start_a7
    invoke-virtual {v5}, Ljava/io/BufferedReader;->close()V
    :try_end_aa
    .catchall {:try_start_a7 .. :try_end_aa} :catchall_ab

    .line 280
    :goto_aa
    goto :goto_ad

    .line 279
    :catchall_ab
    move-exception v4

    goto :goto_aa

    .line 284
    :goto_ad
    :try_start_ad
    invoke-static {v3}, Ljava/util/Collections;->unmodifiableSet(Ljava/util/Set;)Ljava/util/Set;

    move-result-object v3

    sput-object v3, Lcom/android/server/am/FcmWakeFilter;->sPackageFilterSet:Ljava/util/Set;

    .line 285
    sput v2, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I

    .line 286
    sput-wide v6, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J
    :try_end_b7
    .catchall {:try_start_ad .. :try_end_b7} :catchall_c4

    .line 291
    goto :goto_cb

    .line 276
    :catchall_b8
    move-exception v2

    move-object v4, v5

    goto :goto_bc

    :catchall_bb
    move-exception v2

    :goto_bc
    if-eqz v4, :cond_c3

    .line 278
    :try_start_be
    invoke-virtual {v4}, Ljava/io/BufferedReader;->close()V
    :try_end_c1
    .catchall {:try_start_be .. :try_end_c1} :catchall_c2

    .line 280
    goto :goto_c3

    .line 279
    :catchall_c2
    move-exception v3

    .line 282
    :cond_c3
    :goto_c3
    :try_start_c3
    throw v2
    :try_end_c4
    .catchall {:try_start_c3 .. :try_end_c4} :catchall_c4

    .line 287
    :catchall_c4
    move-exception v2

    .line 289
    const-wide/16 v2, -0x1

    :try_start_c7
    sput-wide v2, Lcom/android/server/am/FcmWakeFilter;->sLastModified:J

    .line 290
    sput v1, Lcom/android/server/am/FcmWakeFilter;->sCurrentMode:I
    :try_end_cb
    .catchall {:try_start_c7 .. :try_end_cb} :catchall_cd

    .line 292
    :goto_cb
    monitor-exit v0

    return-void

    .line 236
    :catchall_cd
    move-exception v1

    :try_start_ce
    monitor-exit v0
    :try_end_cf
    .catchall {:try_start_ce .. :try_end_cf} :catchall_cd

    throw v1
.end method
