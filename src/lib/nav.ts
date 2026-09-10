export const navLinks = [
  { href: "/", label: "Dashboard" },
  { href: "/scan", label: "Scan" },
] as const;

export function navIsActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  return pathname === href || pathname.startsWith(`${href}/`);
}
