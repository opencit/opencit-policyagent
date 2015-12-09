#!/usr/bin/env python

import argparse
from distutils.spawn import find_executable as which
import os
from platform import linux_distribution as flavour
import shutil

config = None
LOG = None

import logging as loging
import logging.config as logging_config

MODULE_NAME = 'policyagent'
POLICY_AGENT_PROPERTIES_FILE = '/opt/policyagent/configuration/policyagent.properties'
INIT_DIR='/etc/init.d'
STARTUP_SCRIPT_NAME='policyagent-init'
PA_HOME='/opt/policyagent'

def version():
    LOG.info('policyagent-0.1')

def launch(args):
    try:
        if os.path.isfile(args['base_image']):
            policy_location = None
            instance_dir = os.path.join(config['INSTANCES_DIR'],args['instance_id'])
            #Retrieve the store module from TrustPolicyRetrieval factory depending on the trustpolicy location provided
            store = TrustPolicyRetrieval.trustPolicy(args['mtwilson_trustpolicy_location'])
            if store is not None:
                #Here we get the policy from the store which we retrieved from the previous step
                policy_location = store.getPolicy(args['image_id'], config)
                #copy the policy in the instance directory
                shutil.copy(policy_location, os.path.join(instance_dir,'trustpolicy.xml'))
            else:
                LOG.exception("Mtwilson_trustpolicy_location is None")
                raise Exception("Mtwilson_trustpolicy_location is None")
            if policy_location is not None:
                LOG.info('Verifiying trust policy signature ...')
                xml_parser = ProcessTrustpolicyXML(policy_location)
                if xml_parser.verify_trust_policy_signature(config['TAGENT_LOCATION'], policy_location):
                    #generate stripped xml with whitelist
                    xml_parser.generate_manifestlist_xml(instance_dir)
                    #retrieve encryption element which has dek_url and checksum
                    encryption_element = xml_parser.retrieve_chksm()
                    if encryption_element is not None:
                        crypt = Crypt(config=config)
                        decfile = crypt.decrypt(image_id=args['image_id'],
                                                image=os.path.join(config['INSTANCES_DIR'], '_base', args['image_id']),
                                                dek_url=encryption_element['DEK_URL'],
                                                instance_dir=instance_dir,
                                                root_disk_size_gb=args['root_disk_size_gb'],
                                                instance_id=args['instance_id'])
                        LOG.debug("Expected md5sum : " + encryption_element['CHECKSUM'])
                        #generate md5sum for the decrypted image
                        current_md5 = utils.generate_md5(decfile)
                        LOG.debug("Current md5sum : " + current_md5)
                        if current_md5 != encryption_element['CHECKSUM']:
                            LOG.exception("checksum mismatch")
                            raise Exception("checksum mismatch")
                else:
                    LOG.exception("Trustpolicy signature mismatch. Aborting launch.")
                    raise Exception("Trustpolicy signature mismatch.")
            else:
                LOG.exception("policy location has None value")
                raise Exception("policy location has None value")
        else:
            LOG.exception("File not found" + args['base_image'])
            raise Exception("File not found")
    except Exception as e:
        LOG.exception("Failed during launch call " + str(e.message))
        raise e

def delete(args):
    try :
        enc_inst = Crypt(config=config)
        enc_inst.delete(instance_path=args['instance_path'])
    except Exception as e:
        LOG.exception("Failed during delete call " + str(e.message))
        raise e

def init_logger():
    #initialize logger
    logging_config.fileConfig(fname = config['LOGGING_CONFIG_PATH'])
    #logging_config.fileConfig(fname = LOGGING_CONFIG_PATH)
    global LOG
    LOG = loging.getLogger(MODULE_NAME)

def init_config():
    #initialize properties
    prop_parser = ParseProperty()
    global config
    config = prop_parser.create_property_dict(POLICY_AGENT_PROPERTIES_FILE)


def remount():
    if not os.path.isdir(config['DISK_LOCATION']):
        LOG.warning(config['DISK_LOCATION'] + ' directory does not exists.')
        return
    if not os.path.isdir(config['ENC_KEY_LOCATION']):
        os.mkdir(config['ENC_KEY_LOCATION'])
    # For all the sparse files present in the /var/lib/nova/instances/enc_disk directories mount encrypted discs using
    # encrypted loop device
    crypt = Crypt(config)
    for enc_file in os.listdir(config['DISK_LOCATION']):
        LOG.debug("Processing {0}".format(enc_file))
        try:
            key_path = os.path.join(config['ENC_KEY_LOCATION'], "{0}{1}".format(enc_file, Crypt.KEY_EXTN))
            LOG.debug("Key path: {0}".format(key_path))
            image_id = enc_file
            if not os.path.isfile(key_path):
                LOG.debug("Key not found at {0}. Downloading key again".format(key_path))
                policy_location = os.path.join(config['INSTANCES_DIR'], '_base', "{0}.trustpolicy.xml".format(image_id))
                LOG.debug("Policy location: {0}".format(policy_location))
                if not os.path.isfile(policy_location):
                    LOG.info("Policy doesn't exist at {0}".format(policy_location))
                    continue
                xml_parser = ProcessTrustpolicyXML(policy_location)
                dek_url = xml_parser.retrieve_chksm()['DEK_URL']
                crypt.request_dek(dek_url, key_path)
            LOG.debug("Creating and mounting encrypted device: {0}".format(image_id))
            crypt.create_encrypted_device(image_id, os.path.join(config['MOUNT_LOCATION'], image_id),
                                          os.path.join(config['DISK_LOCATION'], image_id), key_path, False)
        except Exception as e:
            LOG.error('Failed while mounting encrypted device: {0}'.format(enc_file))
            LOG.exception(e.message)
            continue


def uninstall():
    #First step is to unregister the startup script using update-rc.d or chkconfig depending on the linux flavour
    pa_init = which(STARTUP_SCRIPT_NAME)
    if flavour()[0] == 'Ubuntu':
        cmd = which('update-rc.d')
        update_rc_d = utils.create_subprocess([cmd, '-f', pa_init, 'remove'])
        utils.call_subprocess(update_rc_d)
        if update_rc_d.returncode != 0:
            LOG.error("Failed to execute update-rc.d command. Exit code = " + str(update_rc_d.returncode))
            raise Exception("Failed to remove statrup script")

    if flavour()[0] == 'Red Hat Enterprise Linux Server':
        cmd = which('chkconfig')
        chkconfig = utils.create_subprocess([cmd, '--del', pa_init])
        utils.call_subprocess(chkconfig)
        if chkconfig.returncode != 0:
            LOG.error("Failed to execute chkconfig command. Exit code = " + str(chkconfig.returncode))
            raise Exception("Failed to remove startup script")

    if os.path.exists(INIT_DIR) and os.path.isdir(INIT_DIR):
        STARTUP_SCRIPT=os.path.join(INIT_DIR, STARTUP_SCRIPT_NAME)
        LOG.debug("Removing startup script : " + STARTUP_SCRIPT)
        os.remove(STARTUP_SCRIPT)


    #Remove policyagent-init symlink
    os.remove(pa_init)
    pa = which(MODULE_NAME)
    #Remove policyagent symlink
    os.remove(pa)
    #Remove the policyagent directory
    if os.path.exists(PA_HOME) and os.path.isdir(PA_HOME):
        shutil.rmtree(PA_HOME)

    #Remove the selinux policy in case of RHEL
    if flavour()[0] == 'Red Hat Enterprise Linux Server':
        semodule = utils.create_subprocess(['semodule', '-r', 'policyagent'])
        utils.call_subprocess(semodule)
        if semodule.returncode != 0:
            LOG.error("Failed to execute semodule command. Exit code = " + str(semodule.returncode))
            raise Exception("Failed to remove selinux policy")

def container_launch(args):
    mount_path = args['root_path']
    LOG.info('Mount Path : ' + mount_path)
    policy_location = os.path.join(mount_path, args['mtwilson_trustpolicy_location'][1:])
    LOG.info('Trust_policy : ' + policy_location)
    if os.path.exists(policy_location):
        xml_parser = ProcessTrustpolicyXML(policy_location)
        #if xml_parser.verify_trust_policy_signature(config['TAGENT_LOCATION'], policy_location):
        instance_uuid_process = utils.create_subprocess(['docker', 'inspect', '-f', '{{.Name}}', args['container_id']])
        out = utils.call_subprocess(instance_uuid_process)
        instance_uuid = out[0][6:]
        LOG.info('Instance UUID : ' + instance_uuid)
        container_dir = os.path.join(config['CONTAINERS_DIR'], args['container_id'])
        if not os.path.exists(config['TRUSTREPORTS_DIR']):
            os.mkdir(config['TRUSTREPORTS_DIR'])
            os.chmod(config['TRUSTREPORTS_DIR'], 0775)
        instance_dir = os.path.join(config['TRUSTREPORTS_DIR'], instance_uuid)
        if not os.path.exists(instance_dir):
            os.mkdir(instance_dir)
            os.chmod(instance_dir, 0775)
            shutil.copy(policy_location, os.path.join(instance_dir, 'trustpolicy.xml'))
            os.chmod(os.path.join(instance_dir, 'trustpolicy.xml'), 0664)
            xml_parser.generate_manifestlist_xml(instance_dir)
            os.chmod(os.path.join(instance_dir, 'manifest.xml'), 0664)

        vrtm = VRTMReq()
        xml_string = vrtm.vrtm_generate_xml('method', '-mount_path', mount_path, '-manifest', os.path.join(container_dir,'trustpolicy.xml'), '-uuid', instance_uuid, '-docker_instance')
        LOG.info('vRTM Request : ')
        LOG.info(xml_string)
        vrtm.measure_vm(xml_string, {'VRTM_IP' : '127.0.0.1', 'VRTM_PORT' : '16005'})


# execute only if imported as module
if __name__ == "__main__":
    from commons.parse import ParseProperty
    init_config()
    init_logger()
    try:
        from trustpolicy.trust_policy_retrieval import TrustPolicyRetrieval
        from commons.process_trust_policy import ProcessTrustpolicyXML
        import commons.utils as utils
        from encryption.crypt import Crypt
        from invocation.measure_vm import VRTMReq
        parser = argparse.ArgumentParser()
        subparsers = parser.add_subparsers()
        #version command parser
        version_parser = subparsers.add_parser("version")
        version_parser.set_defaults(func = version)
        #VM launch command parser
        launch_parser = subparsers.add_parser("launch")
        launch_parser.add_argument("base_image")
        launch_parser.add_argument("image_id")
        launch_parser.add_argument("instance_id")
        launch_parser.add_argument("mtwilson_trustpolicy_location")
        launch_parser.add_argument("root_disk_size_gb", type=int)
        launch_parser.set_defaults(func = launch)
        #VM delete command parser
        delete_parser = subparsers.add_parser("delete")
        delete_parser.add_argument("instance_path")
        delete_parser.set_defaults(func = delete)
        #enc disc remount command parser
        remount_parser = subparsers.add_parser("remount")
        remount_parser.set_defaults(func=remount)
        #policyagent uninstall command parser
        uninstall_parser = subparsers.add_parser("uninstall")
        uninstall_parser.set_defaults(func = uninstall)
        #docker container launch command parser
        container_launch_parser = subparsers.add_parser("container_launch")
        container_launch_parser.add_argument("root_path")
        container_launch_parser.add_argument("image_id")
        container_launch_parser.add_argument("container_id")
        container_launch_parser.add_argument("mtwilson_trustpolicy_location")
        container_launch_parser.set_defaults(func = container_launch)

        args = parser.parse_args()
        dict_args = vars(args)
        dict_len = len(dict_args)
        if dict_len > 1:
            args.func(dict_args)
        else:
            args.func()
    except Exception as e:
        LOG.exception("Failed while executing policyagent..")
        raise e

