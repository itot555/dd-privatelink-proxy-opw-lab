import { datadogRum } from "@datadog/browser-rum";

export function initRum(): void {
  if (import.meta.env.VITE_ENABLE_RUM !== "true") {
    return;
  }

  const applicationId = import.meta.env.VITE_RUM_APPLICATION_ID;
  const clientToken = import.meta.env.VITE_RUM_CLIENT_TOKEN;
  const site = import.meta.env.VITE_DD_SITE || "datadoghq.com";
  const env = import.meta.env.VITE_DD_ENV || "dd-lab";
  const version = import.meta.env.VITE_DD_VERSION || "1.0.0";

  if (!applicationId || !clientToken) {
    console.warn("RUM is enabled but applicationId/clientToken are missing");
    return;
  }

  try {
    datadogRum.init({
      applicationId,
      clientToken,
      site,
      service: "dd-lab-banking-ui",
      env,
      version,
      sessionSampleRate: 100,
      sessionReplaySampleRate: 20,
      traceSampleRate: 100,
      trackUserInteractions: true,
      trackResources: true,
      trackLongTasks: true,
      defaultPrivacyLevel: "mask-user-input",
      // RUM → APM trace 相関（CloudFront 同一 origin の /api/* へ tracecontext 注入）
      allowedTracingUrls: [
        {
          match: window.location.origin,
          propagatorTypes: ["tracecontext"],
        },
      ],
    });

    datadogRum.startSessionReplayRecording();
  } catch (error) {
    console.warn("RUM init failed — continuing without RUM", error);
  }
}

export function setRumUser(loginId: string, displayName: string): void {
  if (import.meta.env.VITE_ENABLE_RUM !== "true") {
    return;
  }
  datadogRum.setUser({
    id: loginId,
    name: displayName,
  });
}

export function clearRumUser(): void {
  if (import.meta.env.VITE_ENABLE_RUM !== "true") {
    return;
  }
  datadogRum.clearUser();
}

export function trackRumView(viewName: string): void {
  if (import.meta.env.VITE_ENABLE_RUM !== "true") {
    return;
  }
  try {
    datadogRum.startView({ name: viewName });
  } catch {
    // RUM 未初期化時は無視
  }
}
