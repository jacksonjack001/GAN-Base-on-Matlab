clear;
clc;
addpath('base', 'activation', 'error_term', 'gradient');
% -----------load mnist data
load('mnist_uint8', 'train_x');
train_x = double(reshape(train_x, 60000, 28, 28))/255;
train_x = permute(train_x,[1,3,2]);
batch_size = 60;
% ----------- model
generator.layers = {
    struct('type', 'input', 'output_shape', [batch_size, 100]) 
    struct('type', 'fully_connect', 'output_shape', [batch_size, 28*28*3], 'activation', 'leaky_relu')
    struct('type', 'reshape', 'output_shape', [batch_size, 28,28,3])
    struct('type', 'conv2d', 'output_maps', 2, 'kernel_size', 5, 'padding', 'valid', 'activation', 'leaky_relu')
    struct('type', 'reshape', 'output_shape', [batch_size, 24*24*2])
    struct('type', 'fully_connect', 'output_shape', [batch_size, 28*28], 'activation', 'sigmoid')
    struct('type', 'reshape', 'output_shape', [batch_size, 28, 28])
};
discriminator.layers = {
    struct('type', 'input', 'output_shape', [batch_size, 28, 28, 1])
    struct('type', 'reshape', 'output_shape', [batch_size, 28*28])
    struct('type', 'fully_connect', 'output_shape', [batch_size, 1024], 'activation', 'leaky_relu')
    struct('type', 'fully_connect', 'output_shape', [batch_size, 1], 'activation', 'sigmoid')
};
generator = nn_setup(generator);
discriminator = nn_setup(discriminator);
% ----------- setting
epoch = 100;
images_num = 60000;
batch_num = ceil(images_num / batch_size);
learning_rate = 0.001;
for e=1:epoch
    kk = randperm(images_num);
    for t=1:batch_num
        % perpare data
        images_real = train_x(kk((t - 1) * batch_size + 1:t * batch_size), :, :);
        noise = unifrnd(-1, 1, batch_size, 100);
        % tranning
        % -----------generator is fixed��update discriminator
        generator = nn_ff(generator, noise);
        images_fake = generator.layers{end}.a;
        discriminator = nn_ff(discriminator, images_fake);
        logits_fake = discriminator.layers{end}.z;
        discriminator = nn_bp_d(discriminator, logits_fake, ones(batch_size, 1));
        generator = nn_bp_g(generator, discriminator);
        generator = nn_applygrads_adam(generator, learning_rate);
        % -----------discriminator is fixed��update generator
        generator = nn_ff(generator, noise);
        images_fake = generator.layers{end}.a;
        images = [images_fake;images_real];
        discriminator = nn_ff(discriminator, images);
        logits = discriminator.layers{end}.z;
        labels = [zeros(batch_size,1);ones(batch_size,1)];
        discriminator = nn_bp_d(discriminator, logits, labels);
        discriminator = nn_applygrads_adam(discriminator, learning_rate);
        % ----------------output loss
        if t == batch_num || mod(t, 500)==0
            c_loss = sigmoid_cross_entropy(logits(1:batch_size), ones(batch_size, 1));
            d_loss = sigmoid_cross_entropy(logits, labels);
            fprintf('c_loss:"%f",d_loss:"%f"\n',c_loss, d_loss);
        end
        if t == batch_num || mod(t, 500)==0
            path = ['./pics/epoch_',int2str(e),'_t_',int2str(t),'.png'];
            save_images(images_fake, [4, 4], path);
            fprintf('save_sample:%s\n', path);
        end
    end
end