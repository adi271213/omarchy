echo "Prioritize the Omarchy package repository over Arch repositories"

# Move the existing section rather than replacing pacman.conf so channel URLs,
# custom repositories, and administrator options survive the migration.
#
# Stage the rewritten config as root inside /etc, a directory the unprivileged
# desktop user cannot write to, so the path `sudo install` reopens cannot be
# swapped between the check and the privileged write (TOCTOU). Staging on the
# destination filesystem also keeps the final install an atomic replacement.
pacman_config=$(sudo mktemp /etc/pacman.conf.XXXXXX)
trap 'sudo rm -f "$pacman_config"' EXIT

awk '
  /^[[:space:]]*\[[^]]+\]/ {
    section = $0
    sub(/^[[:space:]]*\[/, "", section)
    sub(/\].*$/, "", section)
    if (section != "options") repositories = 1
  }
  !repositories { prefix = prefix $0 "\n"; next }
  section == "omarchy" { omarchy = omarchy $0 "\n"; next }
  { others = others $0 "\n" }
  END { printf "%s%s%s", prefix, omarchy, others }
' /etc/pacman.conf | sudo tee "$pacman_config" >/dev/null

if ! cmp -s /etc/pacman.conf "$pacman_config"; then
  sudo cp -a /etc/pacman.conf /etc/pacman.conf.bak
  sudo install -m 644 -o root -g root "$pacman_config" /etc/pacman.conf
fi

# Refresh databases and upgrade against the new repository priority. Run this
# even when the config is already ordered so a failed upgrade can be retried.
omarchy-update-system-pkgs
