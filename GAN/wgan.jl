"""
HyperParamsWGAN

Hyper-parameters for the wasserstein GAN:

```julia
@with_kw struct HyperParamsWGAN
    noise_model = Normal(0.0f0, 1.0f0)
    target_model = Normal(23.0f0, 1.0f0)
    data_size::Int = 10000
    batch_size::Int = 100
    latent_dim::Int = 1
    epochs::Int = 20
    n_critic::Int = 5
    clip_value::Float32 = 0.01
    lr_dscr::Float64 = 0.00005
    lr_gen::Float64 = 0.00005
end
```
"""
@with_kw struct HyperParamsWGAN
    noise_model = Normal(0.0f0, 1.0f0)
    target_model = Normal(23.0f0, 1.0f0)
    data_size::Int = 10000
    batch_size::Int = 100
    latent_dim::Int = 1
    epochs::Int = 20
    n_critic::Int = 5
    clip_value::Float32 = 0.01
    lr_dscr::Float64 = 0.00005
    lr_gen::Float64 = 0.00005
end


function wasserstein_loss_discr(real, fake)
    return -mean(real) + mean(fake)
end

function wasserstein_loss_gen(out)
    return -mean(out)
end

function train_discr(discr, original_data, fake_data, opt_discr, hparams::HyperParamsWGAN)
    loss = 0.0
    for i in 1:(hparams.n_critic)
        loss, grads = Flux.withgradient(discr) do discr
            wasserstein_loss_discr(discr(original_data), discr(fake_data'))
        end
        update!(opt_discr, discr, grads[1])
        for i in Flux.params(discr)
            i = clamp.(i, -hparams.clip_value, hparams.clip_value)
        end
    end
    return loss
end

Zygote.@nograd train_discr

function train_gan(gen, discr, original_data, opt_gen, opt_discr, hparams::HyperParamsWGAN)
    noise = gpu(
        rand!(
            hparams.noise_model,
            similar(original_data, (hparams.batch_size, hparams.latent_dim)),
        ),
    )
    loss = Dict()
    loss["gen"], grads = Flux.withgradient(gen) do gen
        fake_ = gen(noise)
        loss["discr"] = train_discr(discr, original_data, fake_, opt_discr, hparams)
        wasserstein_loss_gen(discr(fake_'))
    end
    update!(opt_gen, gen, grads[1])
    return loss
end

"""
    train_wgan(dscr, gen, hparams::HyperParamsVanillaGan)

Train the vanilla GAN. `dscr` is the neural-network model for the discriminator,
`gen` is the neural-network model for the generator,
and `hparams` is the hyper-parameters for the training.
"""
function train_wgan(dscr, gen, hparams::HyperParamsWGAN)
    #hparams = HyperParams()

    train_set = Float32.(rand(hparams.target_model, hparams.data_size))
    loader = gpu(
        Flux.DataLoader(
            train_set; batchsize=hparams.batch_size, shuffle=true, partial=false
        ),
    )

    #dscr = discriminator(hparams)
    #gen = gpu(generator(hparams))

    opt_dscr = Flux.setup(Flux.Adam(hparams.lr_dscr), dscr)
    opt_gen = Flux.setup(Flux.Adam(hparams.lr_gen), gen)
    losses_gen = []
    losses_dscr = []

    train_steps = 0
    @showprogress for epoch in 1:(hparams.epochs)
        for x in loader
            loss = train_gan(gen, dscr, x, opt_gen, opt_dscr, hparams)
            train_steps += 1
            push!(losses_gen, loss["gen"])
            push!(losses_dscr, loss["discr"])
        end
    end
    return (losses_gen, losses_dscr)
end
