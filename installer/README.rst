Bootstrapping vanilla Raspbian image
====================================
To bootstrap a vanilla Raspbian system, run the following command and provide password ``raspbian`` for the default Raspbian user ``pi``:

.. code-block:: bash
    ansible-playbook -i hosts rpi-bootstrap.yml --ask-pass
