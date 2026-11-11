import Link from "next/link";
import { SignInForm } from "@/features/auth/presentation/sign-in-form";
export default function SignInPage() { return <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-16"><h1 className="text-2xl font-semibold">Sign in</h1><p className="mt-2 text-sm text-slate-600">Access your professional workspace.</p><div className="mt-8"><SignInForm /></div><p className="mt-6 text-sm text-slate-600">New professional? <Link className="font-medium underline" href="/sign-up">Create an account</Link></p></main>; }
