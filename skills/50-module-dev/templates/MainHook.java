package com.example.mymodule;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.widget.Toast;

/**
 * modern（libxposed）模块入口骨架。
 *
 * 三条纪律（BOOK 6.1 / 6.3）：
 *  1. 入口声明走 META-INF/xposed/module.prop + java_init.list，本类全限定名写进 java_init.list；
 *  2. 业务 hook 必须在 Application.attach(Context) 之后安装，并使用 attach 传入的 ClassLoader；
 *     不要在 onPackageLoaded 阶段用模块自己的 loader 去解析目标类（会 ClassNotFound）；
 *  3. 默认保留用户可见反馈（Toast + 固定日志 tag），除非用户明确要求静默。
 *
 * 注意：本文件是**结构骨架**。不同 libxposed API 版本的基类与方法签名不同，
 *      落地前按你工程依赖的 API 版本补齐（待补充：语料未固定 API 版本与方法签名）。
 */
public class MainHook {
    public static final String TAG = "VectorToastModule";

    /** 由框架在目标进程启动早期调用；ctx 是目标应用的 Context。 */
    public void onAttach(Context ctx) {
        final String pkg = ctx.getPackageName();
        Log.i(TAG, "hooked Application.attach for package=" + pkg);

        // 用户可见反馈：主线程弹 Toast（模块是否真的进了目标进程，一眼可见）
        new Handler(Looper.getMainLooper()).post(() ->
                Toast.makeText(ctx, "Vector 注入成功: " + pkg, Toast.LENGTH_SHORT).show());

        // 业务 hook：一定要用 ctx.getClassLoader()
        ClassLoader cl = ctx.getClassLoader();
        try {
            Class<?> target = Class.forName("com.example.target.SomeClass", false, cl);
            installHooks(target);
            Log.i(TAG, "injected package=" + pkg + " process=" + android.os.Process.myPid());
        } catch (Throwable t) {
            Log.e(TAG, "hook install failed for " + pkg, t);
        }
    }

    private void installHooks(Class<?> target) {
        // TODO: 按目标方法签名挂 hook；示范：
        //   hook(target, "isVip", () -> true);
        //   hook(target, "getSign", args -> computeSign(args));
    }
}
