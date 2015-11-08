#!/usr/bin/python
import os
import logging
import logging.config
from commons.pa_parse import ParseProperty
import commons.pa_utils as pa_utils

dev_map='/dev/mapper'

def mount_enc_partitions():

    for key in os.listdir(pa_config['ENC_KEY_LOCATION']):
        key_filepath = os.path.join(pa_config['ENC_KEY_LOCATION'], key)
        image_id = key.split('.')[0]
        #Get loop device
        loop_dev = pa_utils.get_loop_device(os.path.join(pa_config['DISK_LOCATION'], image_id))

        luks_open_proc_1 = pa_utils.create_subprocess([pa_config['TPM_UNBIND_AES_KEY'], '-k', pa_config['PRIVATE_KEY'], '-i', key_filepath, '-q', ta_config['binding.key.secret'], '-x'])
        luks_open_proc_2 = pa_utils.create_subprocess(['cryptsetup', '-v', 'luksOpen', '--key-file=-', loop_dev, image_id], stdin=luks_open_proc_1.stdout)
        pa_utils.call_subprocess(luks_open_proc_2)
        if luks_open_proc_2.returncode != 0:
            LOG.exception('Failed to perform luksopen')
            raise Exception('Failed to perform luksopen')
        device_mapper = os.path.join(dev_map, image_id)
        image_realpath = os.path.join(pa_config['MOUNT_LOCATION'], image_id)
        mount_process = pa_utils.create_subprocess(['mount', '-t', 'ext4', device_mapper, image_realpath])
        pa_utils.call_subprocess(mount_process)
        if mount_process.returncode != 0:
            LOG.exception('Failed to perform mount')
            raise Exception('Failed to perform mount')
    
def init_config():
    #initialize properties and logger
    prop_parser = ParseProperty()
    global pa_config
    pa_config = prop_parser.pa_create_property_dict("/opt/policyagent/configuration/policyagent.properties")
    global ta_config
    ta_config = prop_parser.pa_create_property_dict(pa_config['TRUST_AGENT_PROPERTIES'])

def init_logger():
    logging.config.fileConfig(fname='/opt/policyagent/configuration/logging_properties.cfg')
    global LOG
    LOG = logging.getLogger(__name__)

if __name__ == "__main__":
    init_logger()
    init_config()
    mount_enc_partitions()