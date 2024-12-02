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

static ERL_NIF_TERM nif_slave_config_pdos(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    // TODO pass ec_sync_info_t list through nif and configure the following call
    static const ec_sync_info_t ek1100_syncs[] = {
        {0, EC_DIR_OUTPUT},
        {1, EC_DIR_INPUT},
        {0xff}
    };
    if (ecrt_slave_config_pdos(slave_config, EC_END, ek1100_syncs)) {
        enif_make_atom(env, "error");
    }
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_activate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    if (ecrt_master_activate(master)) enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_send(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ecrt_domain_queue(domain);
    ecrt_master_send(master);
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_receive(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ecrt_master_receive(master);
    ecrt_domain_process(domain);
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_state(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ecrt_master_state(master, &master_state);
    return enif_make_atom(env, "ok");
}

static void unload(ErlNifEnv* env, void* priv_data) {
    if (master) ecrt_release_master(master);
}

// NIF definition
static ErlNifFunc nif_funcs[] = {
    {"request_master", 0, nif_request_master},
    {"master_create_domain", 0, nif_master_create_domain},
    {"master_slave_config", 4, nif_master_slave_config},
    {"slave_config_pdos", 1, nif_slave_config_pdos},
    {"master_activate", 0, nif_master_activate},
    {"master_send", 0, nif_master_send},
    {"master_receive", 0, nif_master_receive},
    {"master_state", 0, nif_master_state}
};

ERL_NIF_INIT(Elixir.EthercatEx.Nif, nif_funcs, NULL, NULL, NULL, unload)
