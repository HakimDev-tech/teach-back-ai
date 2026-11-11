import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "Teach-back AI", description: "A clinician-guided patient understanding platform." };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
