#!/usr/bin/env bash
#
# Собирает список изменений оригинальной книги rust-lang/book по коммитам
# и может обновить раздел «Изменения оригинала после последней синхронизации»
# в приложении H.
#
# Примеры:
#   ./rustbook-ru/tools/collect-upstream-changes.sh
#   ./rustbook-ru/tools/collect-upstream-changes.sh --base 05d114287b
#   ./rustbook-ru/tools/collect-upstream-changes.sh --write
#   ./rustbook-ru/tools/collect-upstream-changes.sh --save-base
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RU_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$RU_DIR/.." && pwd)"
BASE_FILE="$RU_DIR/upstream-base.txt"
PAGE="$RU_DIR/src/appendix-08-whats-new.md"
DEFAULT_UPSTREAM="$(cd -- "$REPO_ROOT/.." && pwd)/book-en"

upstream=""
base=""
head="HEAD"
write=false
save_base=false

usage() {
  cat <<'EOF'
Использование: rustbook-ru/tools/collect-upstream-changes.sh [параметры]

Формирует список коммитов rust-lang/book, изменивших каталог src/, со времени
последней синхронизации перевода.

Параметры:
  --repo PATH    путь к клону rust-lang/book
                 (по умолчанию — book-en рядом с репозиторием перевода)
  --base COMMIT  начальный коммит (по умолчанию — из rustbook-ru/upstream-base.txt)
  --head COMMIT  конечный коммит (по умолчанию — HEAD клона оригинала)
  --write        заменить содержимое между маркерами в приложении H
  --save-base    записать --head в rustbook-ru/upstream-base.txt
                 (вызывать после того, как изменения переведены)
  -h, --help     показать эту справку
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --repo)
        (($# >= 2)) || die "Не хватает значения для --repo"
        upstream="$2"
        shift 2
        ;;
      --base)
        (($# >= 2)) || die "Не хватает значения для --base"
        base="$2"
        shift 2
        ;;
      --head)
        (($# >= 2)) || die "Не хватает значения для --head"
        head="$2"
        shift 2
        ;;
      --write)
        write=true
        shift
        ;;
      --save-base)
        save_base=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Неизвестный аргумент: $1 (см. --help)"
        ;;
    esac
  done
}

resolve_upstream() {
  if [[ -z "$upstream" ]]; then
    upstream="$DEFAULT_UPSTREAM"
  fi

  if [[ ! -f "$upstream/src/ch01-00-getting-started.md" ]]; then
    die "Не найден репозиторий rust-lang/book: $upstream
Склонируйте оригинал рядом с репозиторием перевода:
  git clone https://github.com/rust-lang/book.git \"$DEFAULT_UPSTREAM\"
или укажите путь через --repo."
  fi
}

resolve_base() {
  if [[ -z "$base" ]]; then
    [[ -f "$BASE_FILE" ]] || die "Не задан базовый коммит и нет файла $BASE_FILE"
    base="$(grep -v '^[[:space:]]*#' "$BASE_FILE" | head -n1 | tr -d '[:space:]' || true)"
  fi

  [[ -n "$base" ]] || die "Не удалось прочитать базовый коммит из $BASE_FILE"
}

main() {
  parse_args "$@"
  resolve_upstream
  resolve_base

  local base_sha head_sha commits content begin_count end_count
  base_sha="$(git -C "$upstream" rev-parse --verify --quiet "${base}^{commit}")" \
    || die "Не найден базовый коммит: $base"
  head_sha="$(git -C "$upstream" rev-parse --verify --quiet "${head}^{commit}")" \
    || die "Не найден конечный коммит: $head"

  git -C "$upstream" merge-base --is-ancestor "$base_sha" "$head_sha" \
    || die "Коммит $base_sha не является предком $head_sha"

  if $save_base; then
    printf '%s\n' "$head_sha" > "$BASE_FILE"
    echo "Базовая версия обновлена: $head_sha" >&2
    base_sha="$head_sha"
    if ! $write; then
      exit 0
    fi
  fi

  commits="$(git -C "$upstream" log --no-merges --date=short \
    --pretty=format:'- %cd — [`%h`](https://github.com/rust-lang/book/commit/%H) — %s' \
    "$base_sha..$head_sha" -- src)"

  if [[ -z "$commits" ]]; then
    if [[ "$base_sha" == "$head_sha" ]]; then
      content="_Новых изменений в \`src/\` нет: перевод синхронизирован с коммитом [\`${head_sha:0:8}\`](https://github.com/rust-lang/book/commit/$head_sha)._"
    else
      content="_Новых изменений в \`src/\` нет: ближайший коммит оригинала — [\`${head_sha:0:8}\`](https://github.com/rust-lang/book/commit/$head_sha)._"
    fi
  else
    content="_Изменения в \`src/\` оригинала с [\`${base_sha:0:8}\`](https://github.com/rust-lang/book/commit/$base_sha) по [\`${head_sha:0:8}\`](https://github.com/rust-lang/book/commit/$head_sha) (новые сверху):_"
    content+=$'\n\n'
    content+="$commits"
  fi

  if ! $write; then
    printf '%s\n' "$content"
    return 0
  fi

  begin_count="$(grep -c '<!-- BEGIN UPSTREAM CHANGES -->' "$PAGE" || true)"
  end_count="$(grep -c '<!-- END UPSTREAM CHANGES -->' "$PAGE" || true)"
  if [[ "$begin_count" -ne 1 || "$end_count" -ne 1 ]]; then
    die "В $PAGE должна быть ровно одна пара маркеров BEGIN/END UPSTREAM CHANGES"
  fi

  local content_file page_tmp
  content_file="$(mktemp)"
  page_tmp="$(mktemp)"
  trap 'rm -f "${content_file:-}" "${page_tmp:-}"' EXIT

  printf '%s\n' "$content" > "$content_file"
  awk -v newfile="$content_file" '
    /<!-- BEGIN UPSTREAM CHANGES -->/ {
      print
      while ((getline line < newfile) > 0) print line
      close(newfile)
      inside = 1
      next
    }
    /<!-- END UPSTREAM CHANGES -->/ {
      inside = 0
      print
      next
    }
    !inside { print }
  ' "$PAGE" > "$page_tmp"
  mv "$page_tmp" "$PAGE"

  echo "Обновлён раздел в $PAGE" >&2
}

main "$@"
