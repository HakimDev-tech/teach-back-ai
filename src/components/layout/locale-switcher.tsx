import { setLocaleAction } from "@/app/actions/set-locale";
import { cn } from "@/components/ui/cn";
import { getServerI18n } from "@/i18n/server";

export async function LocaleSwitcher({ className }: { className?: string }) {
  const { locale, t } = await getServerI18n();

  return (
    <form action={setLocaleAction} className={cn("flex items-center gap-2", className)}>
      <label className="sr-only" htmlFor="preferred-locale">
        {t("locale.label")}
      </label>
      <select
        className="min-h-10 rounded-xl border border-line bg-surface px-3 text-xs font-semibold text-ink"
        defaultValue={locale}
        id="preferred-locale"
        name="locale"
      >
        <option value="en">English</option>
        <option value="fr">Français</option>
        <option value="ar">العربية</option>
      </select>
      <button
        className="min-h-10 rounded-xl border border-line bg-surface px-3 text-xs font-semibold text-ink transition-colors hover:bg-surface-muted"
        type="submit"
      >
        {t("locale.apply")}
      </button>
    </form>
  );
}
