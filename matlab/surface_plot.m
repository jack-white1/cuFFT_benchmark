length = 8192;
num_iters = 10;
fileName = strcat('../data/processed_json/dual_axis_dual_tone_result_length_',int2str(length),'_with_',int2str(num_iters),'_samples.json');
str = fileread(fileName);
data_struct = jsondecode(str);

X = extractfield(data_struct,'A_input');
Y = extractfield(data_struct,'B_input');
Z = extractfield(data_struct,'B_output');

counter = 0;
bfloat_x = [];
bfloat_y = [];
bfloat_z = [];
for i=1:numel(data_struct)
    if data_struct(i).precision == 'b'
        bfloat_x = [bfloat_x,data_struct(i).A_input];
        bfloat_y = [bfloat_y,data_struct(i).B_input];
        bfloat_z = [bfloat_z,data_struct(i).B_output];
    end
end

scatter3(bfloat_x,bfloat_y,bfloat_z)
set(gca,'xscale','log','yscale','log','zscale','log')
        