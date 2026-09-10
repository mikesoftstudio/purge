import { ImageResponse } from "next/og";

export const size = { width: 800, height: 800 };
export const contentType = "image/png";

export default function IconImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          background: "#16a364",
        }}
      >
        <svg width="120" height="120" viewBox="0 0 24 24" fill="none">
          <path d="M12 2L2 12l10 10 10-10L12 2z" fill="white" opacity="0.95" />
        </svg>
      </div>
    ),
    { ...size }
  );
}
