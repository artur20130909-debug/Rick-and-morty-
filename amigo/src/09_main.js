// Запуск: загружаем сохранённую память, собираем мозг из встроенной модели и включаем интерфейс.
(function main() {
  const saved = U.store.get(STORE_KEY, {}) || {};
  const brain = new Brain(AMIGO_MODEL, {
    profile: saved.profile, settings: saved.settings, customs: saved.customs,
    onSave: data => U.store.set(STORE_KEY, data),
  });
  const app = new App(brain);
  window.amigo = { brain, app };
  const go = () => app.start();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', go); else go();
})();
