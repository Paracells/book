# Инструменты

## `collect-upstream-changes.sh`

Собирает изменения оригинальной книги [`rust-lang/book`](https://github.com/rust-lang/book)
по коммитам и обновляет раздел «Изменения оригинала после последней синхронизации»
в `src/appendix-08-whats-new.md`.

```console
# клон оригинала (один раз), рядом с репозиторием перевода
git clone https://github.com/rust-lang/book.git ../book-en

# посмотреть новые коммиты
./rustbook-ru/tools/collect-upstream-changes.sh

# записать их в приложение H
./rustbook-ru/tools/collect-upstream-changes.sh --write

# после перевода изменений запомнить новую базовую версию
./rustbook-ru/tools/collect-upstream-changes.sh --save-base
```

Базовая версия хранится в `upstream-base.txt`. Скрипт учитывает только коммиты,
которые меняют `src/` (текст книги), и пропускает merge-коммиты.

Дополнительные параметры: `--repo PATH`, `--base COMMIT`, `--head COMMIT`.
Полная справка: `./rustbook-ru/tools/collect-upstream-changes.sh --help`.
