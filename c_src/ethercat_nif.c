// ethercat_nif.c
#include "erl_nif.h"
#include "ecrt.h"

#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

typedef struct domain_node {
    char name[256];
    ec_domain_t *domain;
    struct domain_node *next;
} domain_node_t;

typedef struct {
    ec_master_t *master;
    domain_node_t *domain_list; // Head of the linked list
} ethercat_context_t;

static domain_node_t *get_domain_by_name(ethercat_context_t *context, const char *name) {
    domain_node_t *current = context->domain_list;
    while (current) {
        if (strcmp(current-> name, name) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

static ERL_NIF_TERM nif_request_master(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t*)enif_priv_data(env);

    context->master = ecrt_request_master(0);
    if (!context->master) return enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_create_domain(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t*)enif_priv_data(env);
    char name[256];

    if(!enif_get_string(env, argv[0], name, sizeof(name), ERL_NIF_LATIN1)) {
        return enif_make_badarg(env);
    }

    // Check for duplicate name
    domain_node_t *current = context->domain_list;
    while (current) {
        if (strcmp(current->name, name) == 0) {
            return enif_make_atom(env, "error");
        }
        current = current->next;
    }

    ec_domain_t *domain = ecrt_master_create_domain(context->master);
    if (!domain) return enif_make_atom(env, "error");

    domain_node_t *new_node = enif_alloc(sizeof(domain_node_t));
    if (!new_node) {
        // unmap domain?
        if (!domain) return enif_make_atom(env, "error");
    }

    strcpy(new_node->name, name);
    new_node->domain = domain;
    new_node->next = context->domain_list;
    context->domain_list = new_node;

    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_remove_domain(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t *)enif_priv_data(env);
    char name[256];

    if (!enif_get_string(env, argv[0], name, sizeof(name), ERL_NIF_LATIN1)) {
        return enif_make_badarg(env);
    }

    domain_node_t *current = context->domain_list;
    domain_node_t *prev = NULL;

    while (current) {
        if (strcmp(current->name, name) == 0) {
            if (prev) {
                prev->next = current->next;
            } else {
                context->domain_list = current->next;
            }

            enif_free(current);
            return enif_make_atom(env, "ok");
        }
        current = current->next;
    }
    return enif_make_atom(env, "error");
}

static ERL_NIF_TERM nif_master_get_slave(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t *)enif_priv_data(env);
    unsigned int index;
    ec_slave_info_t slave_info;

    if (!enif_get_uint(env, argv[0], &index)) {
        return enif_make_badarg(env);
    }

    if (!ecrt_master_get_slave(context->master, index, &slave_info)) {
        return enif_make_atom(env, "error");
    }

    // Construct a map with the fields of `slave_info`.
    ERL_NIF_TERM result = enif_make_new_map(env);

    // Add fields to the map.
    enif_make_map_put(env, result, enif_make_atom(env, "position"),
        enif_make_uint(env, slave_info.position), &result);
    enif_make_map_put(env, result, enif_make_atom(env, "vendor_id"),
        enif_make_uint(env, slave_info.vendor_id), &result);
    enif_make_map_put(env, result, enif_make_atom(env, "product_code"),
        enif_make_uint(env, slave_info.product_code), &result);
    enif_make_map_put(env, result, enif_make_atom(env, "revision_number"),
        enif_make_uint(env, slave_info.revision_number), &result);
    enif_make_map_put(env, result, enif_make_atom(env, "serial_number"),
        enif_make_uint(env, slave_info.serial_number), &result);
    enif_make_map_put(env, result, enif_make_atom(env, "alias"),
        enif_make_uint(env, slave_info.alias), &result);
    enif_make_map_put(env, result, enif_make_atom(env, "current_on_ebus"),
        enif_make_int(env, slave_info.current_on_ebus), &result);

    // Return the map to Elixir.
    return result;
}

/*
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
*/

static ERL_NIF_TERM nif_master_activate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t *)enif_priv_data(env);
    if (ecrt_master_activate(context->master)) enif_make_atom(env, "error");
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_queue_all_domains(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t *)enif_priv_data(env);

    domain_node_t *current = context->domain_list;
    while (current) {
        ecrt_domain_queue(current->domain);
        current = current->next;
    }

    ecrt_master_send(context->master);
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM nif_master_send(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t *)enif_priv_data(env);
    ecrt_master_send(context->master);
    return enif_make_atom(env, "ok");
}

bool check_domain_state(const ec_domain_t *domain, ErlNifEnv* env) {
    ec_domain_state_t ds;

    ecrt_domain_state(domain, &ds);

    /*
    EC_WC_ZERO          No registered process data were exchanged
    EC_WC_INCOMPLETE    Some of the registered process data were exchanged
    EC_WC_COMPLETE      All registered process data were exchanged
    */
    // TODO  && domain->working_counter_changes check if domain changed
    return ds.wc_state == EC_WC_COMPLETE;
}

static ERL_NIF_TERM nif_cyclic_task(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ethercat_context_t *context = (ethercat_context_t *)enif_priv_data(env);
    ErlNifPid caller_pid;
    if (!enif_self(env, &caller_pid)) return enif_make_atom(env, "error");

    while (1) {
        ecrt_master_receive(context->master);

        domain_node_t *current = context->domain_list;
        while (current) {
            ecrt_domain_process(current->domain);
            if (check_domain_state(current->domain, env)) {
                ERL_NIF_TERM message = enif_make_string(env, "this is a test", ERL_NIF_LATIN1);
                enif_send(env, &caller_pid, NULL, message);
            }
            current = current->next;
        }

    }
    return enif_make_atom(env, "ok");
}

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM info) {
    ethercat_context_t *context = enif_alloc(sizeof(ethercat_context_t));
    if (!context) {
        return -1;
    }

    context->master = NULL;
    context->domain_list = NULL;
    *priv_data = context;
    return 0;
}

static void unload(ErlNifEnv* env, void* priv_data) {
    ethercat_context_t *context = (ethercat_context_t *)priv_data;

    domain_node_t *current = context->domain_list;
    while (current) {
        //ecrt_domain_unmap
        domain_node_t *next = current->next;
        enif_free(current);
        current = next;
    }

    ecrt_release_master(context->master);
    enif_free(context);
}

// NIF definition
static ErlNifFunc nif_funcs[] = {
    {"request_master", 1, nif_request_master},
    {"master_create_domain", 1, nif_master_create_domain},
    {"master_remove_domain", 1, nif_master_remove_domain},
    {"master_get_slave", 1, nif_master_get_slave},
    //{"master_slave_config", 4, nif_master_slave_config},
    //{"slave_config_pdos", 1, nif_slave_config_pdos},
    {"master_activate", 0, nif_master_activate},
    {"master_queue_all_domains", 0, nif_queue_all_domains},
    {"master_send", 0, nif_master_send},
    {"run", 0, nif_cyclic_task, ERL_NIF_DIRTY_JOB_IO_BOUND}
};

ERL_NIF_INIT(Elixir.EthercatEx.Nif, nif_funcs, load, NULL, NULL, unload)
