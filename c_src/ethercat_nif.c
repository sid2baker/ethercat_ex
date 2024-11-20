// ethercat_nif.c
#include "erl_nif.h"
#include "ecrt.h"

// Master state
static ec_master_t *master = NULL;
static ec_master_state_t master_state = {};

static ec_domain_t *domain = NULL;
static ec_domain_state_t domain_state = {};

static ec_slave_config_t *slave_config = NULL;
static ec_slave_config_state_t slave_config_state = {};

static ERL_NIF_TERM nif_request_master(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    master = ecrt_request_master(0);
    if (!master) return enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_create_domain(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    if (!master) return enif_make_atom(env, "error");
    domain = ecrt_master_create_domain(master);
    if (!domain) return enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_slave_config(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    if (!master) return enif_make_atom(env, "error");
    unsigned int alias, position, vendor_id, product_code;

    if (!enif_get_uint(env, argv[0], &alias)) {
        return enif_make_badarg(env);
    }

    if (!enif_get_uint(env, argv[1], &position)) {
        return enif_make_badarg(env);
    }

    if (!enif_get_uint(env, argv[2], &vendor_id)) {
        return enif_make_badarg(env);
    }

    if (!enif_get_uint(env, argv[3], &product_code)) {
        return enif_make_badarg(env);
    }

    slave_config = ecrt_master_slave_config(master, alias, position, vendor_id, product_code);

    if (!slave_config) return enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

// Other functions for PDO, slave configuration, etc.

static void unload(ErlNifEnv* env, void* priv_data) {
    if (master) ecrt_release_master(master);
}

// NIF definition
static ErlNifFunc nif_funcs[] = {
    {"request_master", 0, nif_request_master},
    {"master_create_domain", 0, nif_master_create_domain},
    {"master_slave_config", 4, nif_master_slave_config}
};

ERL_NIF_INIT(Elixir.EthercatEx.Nif, nif_funcs, NULL, NULL, NULL, unload)
