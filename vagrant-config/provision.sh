# Download URL’s for directly downloaded software
PHANTOMJS_URL='https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2'
PRINCE_URL='https://www.princexml.com/download/prince-12.4-linux-generic-x86_64.tar.gz'


# Starting provision

STEP1=true; STEP1NAME='1. Updating OS'
printf '%s\n' "================"
printf '%s\n' " $STEP1NAME "
printf '%s\n' "================"
sudo dnf install -y \
  unzip \
  make cmake \
  gcc gcc-c++ \
  ruby ruby-devel rubygems rubygem-nokogiri \
  graphviz \
  python-devel zlib-devel \
  bison cairo-devel flex \
  gdk-pixbuf2-devel \
  libffi-devel libxml2-devel \
  lyx-fonts \
  pango-devel redhat-rpm-config \
  || STEP1=false
# These are usually already installed:
# sudo dnf install -y tar findutils which wget


STEP2=true; STEP2NAME='2. Installing utility gems'
printf '%s\n' "============================"
printf '%s\n' " $STEP2NAME "
printf '%s\n' "============================"
gem install --no-ri --no-rdoc concurrent-ruby \
  thread_safe epubcheck kindlegen \
  slim \
  haml tilt \
  || STEP2=false


STEP3=true; STEP3NAME='3. Installing AsciiDoctor'
printf '%s\n' "==========================="
printf '%s\n' " $STEP3NAME "
printf '%s\n' "==========================="
gem install --no-ri --no-rdoc asciidoctor --pre || STEP3=false


STEP4=true; STEP4NAME='4. Installing AsciiDoctor PDF'
printf '%s\n' "==============================="
printf '%s\n' " $STEP4NAME "
printf '%s\n' "==============================="
gem install --no-ri --no-rdoc asciidoctor-pdf --pre || STEP4=false


STEP5=true; STEP5NAME='5. Installing AsciiDoctor Mathematical'
printf '%s\n' "========================================"
printf '%s\n' " $STEP5NAME "
printf '%s\n' "========================================"
gem install --no-ri --no-rdoc asciidoctor-mathematical || STEP5=false


STEP6=true; STEP6NAME='6. Installing AsciiDoctor native extensions'
printf '%s\n' "============================================="
printf '%s\n' " $STEP6NAME "
printf '%s\n' "============================================="
gem install --no-ri --no-rdoc asciidoctor-diagram || STEP6=false
gem install --no-ri --no-rdoc asciidoctor-epub3 --pre || STEP6=false


STEP7=true; STEP7NAME='7. Installing syntax highlighters'
printf '%s\n' "==================================="
printf '%s\n' " $STEP7NAME "
printf '%s\n' "==================================="
gem install --no-ri --no-rdoc coderay pygments.rb rouge || STEP7=false


STEP8=true; STEP8NAME='8. Installing auto-cd to /vagrant'
printf '%s\n' "==================================="
printf '%s\n' " $STEP8NAME "
printf '%s\n' "==================================="
if ! grep 'cd /vagrant' /home/vagrant/.bash_profile &>/dev/null; then
  echo "cd /vagrant" >> /home/vagrant/.bash_profile || STEP8=false
else
  printf 'Already installed\n'
fi


STEP9=true; STEP9NAME='9. Installing Prince'
printf '%s\n' "======================"
printf '%s\n' " $STEP9NAME "
printf '%s\n' "======================"
if ! prince --version 2>/dev/null; then
  printf "Downloading Prince..."
  PRINCE_DIST_DIR="$( mktemp -d )"
  curl -sL $PRINCE_URL \
    | sudo tar --strip-components=1 -C "$PRINCE_DIST_DIR" -xzf -
  cd "$PRINCE_DIST_DIR"
  printf '\n' | sudo ./install.sh
  cd /vagrant
  if ! prince --version 2>/dev/null; then
    STEP9=false
    printf 'Failed to install Prince\n' >&2
    printf 'Making PDF’s with Prince will not work\n' >&2
  fi
else
  printf 'Prince is already installed\n'
fi


STEP10=true; STEP10NAME='10. Installing better system fonts'
printf '%s\n' "===================================="
printf '%s\n' " $STEP10NAME "
printf '%s\n' "===================================="
# Enabling RPM Fusion repository
# https://rpmfusion.org/Configuration#Command_Line_Setup_using_rpm
sudo dnf -y install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
  || STEP10=false
sudo dnf -y copr enable dawid/better_fonts || STEP10=false
sudo dnf -y install \
  freetype-freeworld \
  fontconfig-enhanced-defaults \
  fontconfig-font-replacements \
  2>/dev/null \
  || STEP10=false


STEP11=true; STEP11NAME='11. Installing user-provided fonts'
printf '%s\n' "===================================="
printf '%s\n' " $STEP11NAME "
printf '%s\n' "===================================="
for fontfile in /vagrant/vagrant-config/fonts/*.ttf; do
  fontinstalled=false
  fontname=${fontfile##*/}
  fontname=${fontname%.ttf}
  fontname="$( tr '[:upper:]' '[:lower:]' <<< "$fontname" )"
  fontname="${fontname//[^a-zA-Z0-9]/-}"
  sudo mkdir -p "/usr/share/fonts/$fontname"
  if [ -d "/usr/share/fonts/$fontname" ]; then
    sudo cp "$fontfile" "/usr/share/fonts/$fontname" && fontinstalled=true
  fi
  if ! $fontinstalled; then
    STEP11=false
    printf "Failed to install user-provided font '%s'\n" "$fontname" >&2
  fi
done


STEP12=true; STEP12NAME="12. Registering 'Arial Unicode MS' with Prince"
printf '%s\n' "================================================"
printf '%s\n' " $STEP12NAME "
printf '%s\n' "================================================"
if fc-list | grep -qi 'Arial Unicode MS'; then
  if ! grep -q 'Arial Unicode MS' /usr/local/lib/prince/style/fonts.css; then
    sudo sed -i '1s/^/@font-face { font-family: serif; src: prince-lookup("Arial Unicode MS") }\n/' /usr/local/lib/prince/style/fonts.css
    if [ $? = 0 ]; then
      printf "Font 'Arial Unicode MS' has been registered with Prince\n"
    else
      STEP12=false
      printf "Failed to register font 'Arial Unicode MS' with Prince\n" >&2
    fi
  else
    printf "Font 'Arial Unicode MS' is already registered with Prince\n"
  fi
else
  STEP12=false
  printf "Font 'Arial Unicode MS' is NOT provided by the user\n" >&2
  printf 'Everything will work, but some rare symbols might end up missing from Prince PDF’s\n' >&2
fi


STEP13=true; STEP13NAME='13. Building font information caches'
printf '%s\n' "======================================"
printf '%s\n' " $STEP13NAME "
printf '%s\n' "======================================"
fc-cache -v || STEP13=false


STEP14=true; STEP14NAME='14. Installing phantomjs'
printf '%s\n' "=========================="
printf '%s\n' " $STEP14NAME "
printf '%s\n' "=========================="
if ! phantomjs --version &>/dev/null; then
  curl -sL $PHANTOMJS_URL \
    | sudo tar --strip-components=2 -C /usr/local/bin -xjf - *phantomjs
  if ! phantomjs --version &>/dev/null; then
    STEP14=false
    printf 'Failed to install phantomjs\n' >&2
    printf 'Math pre-processing for Prince will not work\n' >&2
  fi
else
  printf 'Phantomjs is already installed\n'
fi


ALL_GOOD=true
printf '%s\n' "==============="
printf '%s\n' " Status report "
printf '%s\n' "==============="

if $STEP1; then
  printf 'SUCCESS: Step %s\n' "$STEP1NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP1NAME" >&2
  ALL_GOOD=false
fi

if $STEP2; then
  printf 'SUCCESS: Step %s\n' "$STEP2NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP2NAME" >&2
  ALL_GOOD=false
fi

if $STEP3; then
  printf 'SUCCESS: Step %s\n' "$STEP3NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP3NAME" >&2
  ALL_GOOD=false
fi

if $STEP4; then
  printf 'SUCCESS: Step %s\n' "$STEP4NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP4NAME" >&2
  ALL_GOOD=false
fi

if $STEP5; then
  printf 'SUCCESS: Step %s\n' "$STEP5NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP5NAME" >&2
  ALL_GOOD=false
fi

if $STEP6; then
  printf 'SUCCESS: Step %s\n' "$STEP6NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP6NAME" >&2
  ALL_GOOD=false
fi

if $STEP7; then
  printf 'SUCCESS: Step %s\n' "$STEP7NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP7NAME" >&2
  ALL_GOOD=false
fi

if $STEP8; then
  printf 'SUCCESS: Step %s\n' "$STEP8NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP8NAME" >&2
  ALL_GOOD=false
fi

if $STEP9; then
  printf 'SUCCESS: Step %s\n' "$STEP9NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP9NAME" >&2
  ALL_GOOD=false
fi

if $STEP10; then
  printf 'SUCCESS: Step %s\n' "$STEP10NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP10NAME" >&2
  ALL_GOOD=false
fi

if $STEP11; then
  printf 'SUCCESS: Step %s\n' "$STEP11NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP11NAME" >&2
  ALL_GOOD=false
fi

if $STEP12; then
  printf 'SUCCESS: Step %s\n' "$STEP12NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP12NAME" >&2
  ALL_GOOD=false
fi

if $STEP13; then
  printf 'SUCCESS: Step %s\n' "$STEP13NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP13NAME" >&2
  ALL_GOOD=false
fi

if $STEP14; then
  printf 'SUCCESS: Step %s\n' "$STEP14NAME"
else
  printf 'FAILED:  Step %s\n' "$STEP14NAME" >&2
  ALL_GOOD=false
fi

if $ALL_GOOD; then
  printf '%s\n' "=========="
  printf '%s\n' " All good "
  printf '%s\n' "=========="
  true
else
  printf '%s\n' "==========" >&2
  printf '%s\n' " Not good " >&2
  printf '%s\n' "==========" >&2
  printf 'Some steps above errored out, check them out\n' >&2
  printf 'Likely, the whole setup won’t work as expected\n' >&2
fi