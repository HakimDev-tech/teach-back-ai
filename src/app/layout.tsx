import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Teach-back AI — Understanding care",
  description:
    "A clinician-guided platform for checking patient understanding of care instructions.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
