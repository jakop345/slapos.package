#include <sys/unistd.h>
#include <sys/cygwin.h>
#include <stdio.h>
#include <errno.h>

int main(int argc, char *argv[])
{
  const char *username = NULL;
  const char *newpwd = NULL;

  if (argc == 1 || argc > 3) {
    fprintf(stderr, "Usage: regpwd username [password]\n");
    return 1;
  }

  username = argv[1];
  if (argc == 3)
    newpwd = argv[2]; 

  if (!strcmp (username, getlogin ()))
    username = NULL;
  
  if (cygwin_internal (CW_SET_PRIV_KEY, newpwd, username)) {
    fprintf(stderr, "Storing password failed: %s", strerror (errno));
    return 1;
  }

  return 0;
}
