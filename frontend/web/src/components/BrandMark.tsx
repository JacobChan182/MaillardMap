type Props = {
  /** Display size in CSS pixels. Uses `logo-nav.png` (72×72) for sharp rendering up to ~36px. */
  size?: number;
};

/** App icon from `public/` — same artwork as the native app icon. */
export function BrandMark({ size = 36 }: Props) {
  return (
    <img
      className="brand__mark brand__mark--img"
      src="/logo-nav.png"
      width={size}
      height={size}
      alt=""
      decoding="async"
      fetchPriority="high"
    />
  );
}
