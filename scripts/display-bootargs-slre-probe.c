/* Native probe linked to the pinned, unmodified U-Boot SLRE implementation.
 * This tests regex behaviour, not U-Boot Hush or physical boot acceptance.
 * Assisted-by: Briar
 */
#include <stdio.h>
#include <string.h>
#include <slre.h>

int main(int argc, char **argv)
{
    struct slre re;

    if (argc != 3)
        return 2;
    if (!slre_compile(&re, argv[1])) {
        fprintf(stderr, "SLRE compile error: %s\n", re.err_str);
        return 2;
    }
    return slre_match(&re, argv[2], strlen(argv[2]), NULL) ? 0 : 1;
}
