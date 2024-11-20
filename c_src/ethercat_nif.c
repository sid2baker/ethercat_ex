// ethercat_nif.c
#include "erl_nif.h"
#include "ecrt.h"

// Master state
static ec_master_t *master = NULL;

static ERL_NIF_TERM nif_request_master(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    master = ecrt_request_master(0);
    if (!master) return enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

// Other functions for PDO, slave configuration, etc.

static void unload(ErlNifEnv* env, void* priv_data) {
    if (master) ecrt_release_master(master);
}

// NIF definition
static ErlNifFunc nif_funcs[] = {
    {"request_master", 0, nif_request_master}
};

ERL_NIF_INIT(Elixir.EthercatEx.Nif, nif_funcs, NULL, NULL, NULL, unload)
