# Debian's login profile resets PATH after the container environment is read.
# Keep user-installed tools discoverable without placing configuration in the
# persistent home volume.
case ":${PATH:-}:" in
  *:/home/agent/.local/bin:*) ;;
  *) PATH="/home/agent/.local/bin${PATH:+:$PATH}" ;;
esac
export PATH
