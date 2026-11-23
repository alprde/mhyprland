# Sunucularda xterm-kitty terminfo'su yok; Backspace/Delete bozuluyor.
# ssh'i xterm-256color ile calistir (kitty'ye ozel ozellikler gerekmiyorsa yeterli).
# Kitty ozellikleri lazimsa: kitten ssh sunucu
function ssh
    env TERM=xterm-256color /usr/bin/ssh $argv
end
