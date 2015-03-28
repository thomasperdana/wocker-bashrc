wocker_usage() {
  echo 'Usage: wocker COMMAND'
  echo ''
  echo 'Commands:'
  echo '    destroy                                     Force remove all containers and related files.'
  echo '    kill CONTAINER                              Kill a running container using SIGKILL or a specified signal.'
  echo '    rm [-f|--force] CONTAINER [CONTAINER...]    Remove one or more containers.'
  echo '                                                  [-f, --force]  Force the removal of a running container (uses SIGKILL)'
  echo '    run [--name=""] [IMAGE]                     Run a new container.'
  echo '                                                  Default docker image: wocker/wocker:latest'
  echo '    start CONTAINER                             Restart a stopped container.'
  echo '    stop CONTAINER                              Stop a running container by sending SIGTERM and then SIGKILL after a grace period.'
  echo '    version | --version | -v                    Show the Wocker version information.'
}

wocker() {

  local version='0.2'
  local red=31
  local image='wocker/wocker:latest'
  local name
  local cname
  local ports
  local cid
  local cids
  local dirname
  local dirnames
  local containers
  local force
  local running
  local confirmation

  case "$1" in

    #
    # $ wocker run
    #
    'run' )

      if [[ "$2" = '--name' ]]; then
        cname="$3"
        image=${4:-$image}
      elif [[ "$2" =~ ^--name=(.*)$ ]]; then
        cname="${BASH_REMATCH[1]}"
        image=${3:-$image}
      else
        cname=""
        image=${2:-$image}
      fi

      if [[ $(docker ps -q) ]]; then
        ports=$(docker inspect --format='{{.NetworkSettings.Ports}}' $(docker ps -q))
      fi

      if [[ $ports =~ "HostIp:0.0.0.0 HostPort:80" ]]; then
        echo -e "\033[${red}mCannot start container $cname: Bind for 0.0.0.0:80 failed: port is already allocated\033[m"

      # Use existing WordPress files to run a container
      elif [[ $cname && -f ~/data/${cname}/wp-config.php ]]; then
        docker run -d --name $cname -p 80:80 -v ~/data/${cname}:/var/www/wordpress:rw $image

      # Or copy WordPress files from the image to run a container
      else

        if [[ $cname ]]; then
          docker run -d --name $cname $image
        else
          docker run -d $image
        fi

        cid=$(docker inspect --format='{{.Id}}' $(docker ps -l -q)) && \
        cid=${cid:0:12} && \
        dirname=$(docker inspect --format='{{.Name}}' $(docker ps -l -q)) && \
        dirname=${dirname#*/} && \
        cname=$dirname
        docker cp $(docker ps -l -q):/var/www/wordpress ~/data/${cid} && \
        mv ~/data/${cid}/wordpress ~/data/${dirname} && \
        rm -rf ~/data/${cid} && \
        docker rm -f $(docker ps -l -q) && \
        docker run -d --name $cname -p 80:80 -v ~/data/${dirname}:/var/www/wordpress:rw $image
      fi

      ;;

    #
    # $ wocker stop | $ wocker kill
    #
    'stop' | 'kill' )

      cid=$(docker inspect --format='{{.Id}}' $2)
      dirname=$(docker inspect --format='{{.Name}}' $2)
      dirname=${cid:0:12}_${dirname#*/}

      docker $1 $cid && \
      mv ~/data/wordpress ~/data/${dirname}

      ;;

    #
    # $ wocker start
    #
    'start' )

      cid=$(docker inspect --format='{{.Id}}' $2)
      dirname=$(docker inspect --format='{{.Name}}' $2)
      dirname=${cid:0:12}_${dirname#*/}

      if [[ $(docker ps -q) ]]; then
        ports=$(docker inspect --format='{{.NetworkSettings.Ports}}' $(docker ps -q))
      fi

      if [[ $ports =~ "HostIp:0.0.0.0 HostPort:80" ]]; then
        echo -e "\033[${red}mCannot start container $name: Bind for 0.0.0.0:80 failed: port is already allocated\033[m"
      elif [[ -f ~/data/wordpress/wp-config.php ]]; then
        echo -e "\033[${red}mPlease move or delete current ~/data/wordpress directory before restarting a stopped container.\033[m"
      elif [[ ! -f ~/data/${dirname}/wp-config.php ]]; then
        echo -e "\033[${red}m~/data/${dirname}: No such directory or files.\033[m"
      else
        mv ~/data/${dirname} ~/data/wordpress && \
        docker start $cid
      fi

      ;;

    #
    # $ wocker rm
    #
    'rm' )

      case "$2" in
        '-f' | '--force' | '--force=true' )
          force=true
          containers=${@:3}
          ;;
        * )
          force=false
          containers=${@:2}
          ;;
      esac

      cids=$(docker inspect --format='{{.Id}}' $containers)

      for cid in $cids; do
        running=$(docker inspect --format='{{.State.Running}}' $cid)
        if [[ $running = true ]]; then
          dirname="wordpress"
        else
          dirname=$(docker inspect --format='{{.Name}}' $cid)
          dirname=${cid:0:12}_${dirname#*/}
        fi

        docker rm --force=${force} $cid
        if [[ $force = true || $running = false ]]; then
          rm -rf ~/data/${dirname}
        fi
      done

      ;;

    #
    # $ wocker update
    #
    'update' )

      curl -O https://raw.githubusercontent.com/wckr/wocker-bashrc/master/bashrc && mv -f bashrc ~/.bashrc && source ~/.bashrc
      docker pull wocker/wocker:latest

      ;;

    #
    # $ wocker destroy
    #
    'destroy' )

      echo 'Are you sure you want to remove all containers and related files? [y/N]'
      read confirmation

      case $confirmation in
        'y' )
          if [[ $(docker ps -a -q) ]]; then
            for cid in $(docker ps -a -q); do
              running=$(docker inspect --format='{{.State.Running}}' $cid)
              if [[ $running = true ]]; then
                dirname="wordpress"
              else
                dirname=$(docker inspect --format='{{.Name}}' $cid)
                dirname=${cid:0:12}_${dirname#*/}
              fi
              rm -rf ~/data/${dirname}
            done
            docker rm -f $(docker ps -a -q)
          fi
          ;;
        * )
          echo 'Containers and file will not be removed, since the confirmation was declined.'
          ;;
      esac
      ;;

    #
    # $ wocker --help | $ wocker -h
    #
    '--help' | '-h' )
      wocker_usage
      ;;

    #
    # $ wocker version | $ wocker --version | $ wocker -v
    #
    'version' | '--version' | '-v' )
      echo "Version: $version"
      ;;

    #
    # Other Docker commands
    #
    'attach' | 'build' | 'commit' | 'cp' | 'create' | 'diff' | 'events' | 'exec' | 'export' | 'history' | 'images' | 'import' | 'info' | 'inspect' | 'load' | 'login' | 'logout' | 'logs' | 'port' | 'pause' | 'ps' | 'pull' | 'push' | 'restart' | 'rmi' | 'save' | 'search' | 'tag' | 'top' | 'unpause' | 'wait' )
      docker $@
      ;;

    #
    # Show Wocker usage
    #
    * )
      wocker_usage
      ;;

  esac
}
