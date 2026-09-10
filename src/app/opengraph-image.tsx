import { ImageResponse } from "next/og";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OGImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
          background: "linear-gradient(135deg, #0a1a14 0%, #0d2b1f 40%, #0f3326 100%)",
          fontFamily: "sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Glow circle */}
        <div
          style={{
            position: "absolute",
            width: 520,
            height: 520,
            borderRadius: "50%",
            background: "radial-gradient(circle, rgba(22,163,100,0.25) 0%, transparent 70%)",
            top: "50%",
            left: "50%",
            transform: "translate(-50%, -50%)",
          }}
        />

        {/* Grid lines */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage:
              "linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)",
            backgroundSize: "60px 60px",
          }}
        />

        {/* Diamond icon */}
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: 16,
            background: "#16a364",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            marginBottom: 28,
            boxShadow: "0 0 40px rgba(22,163,100,0.4)",
            position: "relative",
          }}
        >
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none">
            <path
              d="M12 2L2 12l10 10 10-10L12 2z"
              fill="white"
              opacity="0.95"
            />
          </svg>
        </div>

        {/* App name */}
        <div
          style={{
            fontSize: 80,
            fontWeight: 800,
            color: "white",
            letterSpacing: -2,
            lineHeight: 1,
            position: "relative",
          }}
        >
          Purge
        </div>

        {/* Tagline */}
        <div
          style={{
            fontSize: 24,
            color: "rgba(255,255,255,0.6)",
            marginTop: 16,
            letterSpacing: 0.5,
            position: "relative",
          }}
        >
          Free disk space safely
        </div>

        {/* Feature pills */}
        <div
          style={{
            display: "flex",
            gap: 12,
            marginTop: 36,
            position: "relative",
          }}
        >
          {["Scan caches", "Remove safely", "Multi-platform"].map((text) => (
            <div
              key={text}
              style={{
                padding: "8px 20px",
                borderRadius: 999,
                border: "1px solid rgba(22,163,100,0.3)",
                background: "rgba(22,163,100,0.1)",
                color: "#4ade80",
                fontSize: 15,
                fontWeight: 600,
              }}
            >
              {text}
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div
          style={{
            position: "absolute",
            bottom: 36,
            display: "flex",
            alignItems: "center",
            gap: 8,
            color: "rgba(255,255,255,0.35)",
            fontSize: 14,
          }}
        >
          <span style={{ color: "#16a364", fontWeight: 700 }}>◆</span>
          purge.dev
        </div>
      </div>
    ),
    { ...size }
  );
}
