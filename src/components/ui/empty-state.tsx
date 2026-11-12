type EmptyStateProps = {
  description: string;
  title: string;
};

export function EmptyState({ description, title }: EmptyStateProps) {
  return (
    <section className="rounded-3xl border border-dashed border-line bg-surface px-6 py-12 text-center sm:px-10">
      <div
        aria-hidden="true"
        className="mx-auto grid size-12 place-items-center rounded-2xl bg-brand-soft font-display text-2xl text-brand"
      >
        —
      </div>
      <h2 className="mt-5 font-display text-2xl text-ink">{title}</h2>
      <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-ink-muted">{description}</p>
    </section>
  );
}
