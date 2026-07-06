/// Interruptores de funcionalidades do app.
///
/// A Comunidade está PRONTA (telas, providers, backend), mas desativada por
/// enquanto. Para reativar, basta trocar para `true` — a aba volta ao menu e
/// todas as rotas /community voltam a ser acessíveis.
const bool kCommunityEnabled = false;

/// Liga o teste A/B de paywall. Enquanto `false`, TODO mundo vê a variante A
/// (paywall atual). Quando `true`, cada instalação é sorteada 50/50 entre a
/// variante A e a B (design "Pro"), de forma fixa e persistida.
///
/// Só vire `true` depois que a tela da variante B ([PaywallProPage]) estiver
/// implementada — senão metade dos usuários cairia num placeholder.
const bool kPaywallAbEnabled = false;
