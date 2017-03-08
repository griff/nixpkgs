{ rotational ? ["sda"], rootSize ? "100G"}:

rec {
  storage = 
    let f = dev : ({
      disk.${dev} = {
        clear = true;
        initlabel = true;
      };
      partition = {
        data1.grow = true;
        data1.isPartOf = [ "disk.${dev}" ];
      } // (if isNull rootSize then {}
      else {
        root.size = rootSize;
        root.isPartOf = [ "disk.${dev}" ];
      });
    });
    in map f rotational;
  storage.disks.rescue = {
    id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3729";
    label = "gpt"
    partitions = [ 
    2048,
    {
      type = "linux";
      label = "rescue";
      size = "500M";
    }, {
      type = "raid";
    }];
  };
  storage.disks.data1 = {
    label = "gpt";
    id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3727";
    partitions = [ 
    2048,
    {
      id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3828";
      type = "raid";
    }, {
      id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3829";
      type = "raid";
      size = "20G";
    }];
  };
  storage.disks.data2 = {
    label = "gpt";
    id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3728";
    partitions = [ 
    2048,
    {
      id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3730";
      type = "raid";
    }, {
      id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A3731";
      type = "raid";
      size = "20G";
    }];
  };
  storage.disks.data3 = {
    label = "gpt";
    id = "5FD0DF91-3471-4E1D-AC0F-D8532B443726";
    partitions = [ 
    2048,
    {
      id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A4727";
      partalias = "data3"
      type = "raid";
    }, {
      id = "5FD0DF91-3471-4E1D-AC0F-D8532B4A4728";
      partalias = "root3"
      type = "raid";
      size = "20G";
    }];
  };
  storage.raid.data = {
    type = 5;
    devices = [
      "partitions.data1",
      "partitions.5FD0DF91-3471-4E1D-AC0F-D8532B4A3730",
      "partitions.5FD0DF91-3471-4E1D-AC0F-D8532B4A4727"
    ];
  };
  storage.raid.root = {
    type = 1;
    devices = ["disks.data1.2", "disks.data2.2", "disks.data3.2"]
  };
  storage.fileSystems.data = {
    device = "raid.data.dev"
    fsType = "xfs"
  }
  storage.fileSystems.nixos = {
    device = "raid.root.dev"
    fsType = "ext4"
  }
  fileSystems."/data" = {
    label = "data"
  };
  fileSystems."/" = {
    label = "nixos"
  };
}
